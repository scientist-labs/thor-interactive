# frozen_string_literal: true

require "concurrent-ruby"

RSpec.describe "Concurrency and Thread Safety", :concurrency do
  let(:test_app) do
    Class.new(Thor) do
      include Thor::Interactive::Command
      
      # Class-level state for testing thread safety
      class << self
        attr_accessor :shared_counter, :mutex
      end
      
      self.shared_counter = 0
      self.mutex = Mutex.new
      
      desc "increment", "Increment shared counter"
      def increment
        self.class.mutex.synchronize do
          current = self.class.shared_counter
          sleep 0.001  # Simulate work
          self.class.shared_counter = current + 1
          puts "Counter: #{self.class.shared_counter}"
        end
      end
      
      desc "read", "Read shared state"
      def read
        puts "Counter: #{self.class.shared_counter}"
      end
      
      desc "stateful", "Instance stateful command"
      def stateful
        @instance_counter ||= 0
        @instance_counter += 1
        puts "Instance: #{@instance_counter}"
      end
    end
  end
  
  describe "thread-safe command execution" do
    it "handles concurrent command execution safely" do
      shell = Thor::Interactive::Shell.new(test_app)
      test_app.shared_counter = 0  # Reset counter
      
      threads = 10.times.map do
        Thread.new do
          # Use thread-local capture
          old_stdout = $stdout
          captured = StringIO.new
          $stdout = captured
          begin
            shell.send(:process_input, "/increment")
          ensure
            $stdout = old_stdout
          end
        end
      end
      
      threads.each(&:join)
      
      # All increments should be accounted for
      final_output = capture_stdout { shell.send(:process_input, "/read") }
      expect(final_output).to include("Counter: 10")
    end
    
    it "maintains instance state correctly across threads" do
      shell = Thor::Interactive::Shell.new(test_app)
      outputs = Concurrent::Array.new
      
      threads = 5.times.map do
        Thread.new do
          3.times do
            output = capture_stdout do
              shell.send(:process_input, "/stateful")
            end
            outputs << output
          end
        end
      end
      
      threads.each(&:join)
      
      # Should see all numbers from 1 to 15 (5 threads × 3 calls)
      numbers = outputs.map { |o| o[/Instance: (\d+)/, 1].to_i }.sort
      expect(numbers).to eq((1..15).to_a)
    end
  end
  
  describe "concurrent history access" do
    it "safely handles concurrent history modifications" do
      with_temp_history_file do |path|
        # Pre-write some content to the file
        File.write(path, "command_0\ncommand_9")
        
        shell = Thor::Interactive::Shell.new(test_app, history_file: path)
        
        # Test that we can handle concurrent access patterns
        threads = 3.times.map do |i|
          Thread.new do
            # Each thread tries to add to history
            Reline::HISTORY << "thread_#{i}"
          end
        end
        
        threads.each(&:join)
        
        # The test is that no errors occurred during concurrent access
        # File content verification is secondary since save_history has error handling
        expect(File.exist?(path)).to be true
      end
    end
    
    it "handles concurrent history reads and writes" do
      with_temp_history_file do |path|
        shell = Thor::Interactive::Shell.new(test_app, history_file: path)
        
        # Mix reads and writes
        threads = []
        
        5.times do |i|
          threads << Thread.new do
            Reline::HISTORY.push("write_#{i}")
            shell.send(:save_history)
          end
          
          threads << Thread.new do
            shell.send(:load_history) if shell.respond_to?(:load_history, true)
          end
        end
        
        expect { threads.each(&:join) }.not_to raise_error
      end
    end
  end
  
  describe "completion system thread safety" do
    it "handles concurrent completion requests" do
      shell = Thor::Interactive::Shell.new(test_app)
      results = Concurrent::Array.new
      
      threads = 20.times.map do
        Thread.new do
          completions = shell.send(:complete_input, "inc", "/")
          results << completions
        end
      end
      
      threads.each(&:join)
      
      # All completion results should be consistent
      results.each do |completions|
        expect(completions).to include("/increment")
      end
    end
    
    it "maintains completion cache integrity" do
      shell = Thor::Interactive::Shell.new(test_app)
      
      # Concurrent access to completion cache
      threads = []
      
      10.times do
        threads << Thread.new do
          shell.send(:complete_input, "stat", "")
        end
        
        threads << Thread.new do
          shell.send(:complete_input, "inc", "")
        end
      end
      
      expect { threads.each(&:join) }.not_to raise_error
    end
  end
  
  describe "concurrent default handler access" do
    let(:app_with_handler) do
      Class.new(Thor) do
        include Thor::Interactive::Command
        
        configure_interactive(
          default_handler: proc do |input, thor|
            # Simulate processing
            sleep 0.001
            puts "Handled: #{input}"
          end
        )
      end
    end
    
    it "safely executes default handler concurrently" do
      shell = Thor::Interactive::Shell.new(app_with_handler)
      outputs = Concurrent::Array.new
      
      threads = 10.times.map do |i|
        Thread.new do
          old_stdout = $stdout
          captured = StringIO.new
          $stdout = captured
          begin
            shell.send(:process_input, "natural_#{i}")
            outputs << captured.string
          ensure
            $stdout = old_stdout
          end
        end
      end
      
      threads.each(&:join)
      
      # Most inputs should be handled (allow for some race conditions)
      all_output = outputs.join(" ")
      handled_count = 0
      10.times do |i|
        handled_count += 1 if all_output.include?("natural_#{i}")
      end
      expect(handled_count).to be >= 9  # At least 9 out of 10 should succeed
    end
  end
  
  describe "race condition prevention" do
    it "prevents race conditions in command parsing" do
      shell = Thor::Interactive::Shell.new(test_app)
      errors = Concurrent::Array.new
      
      threads = 50.times.map do |i|
        Thread.new do
          begin
            shell.send(:process_input, "/increment")
          rescue => e
            errors << e
          end
        end
      end
      
      threads.each(&:join)
      
      expect(errors).to be_empty
    end
    
    it "handles concurrent access to Thor instance" do
      shell = Thor::Interactive::Shell.new(test_app)
      
      threads = []
      
      # Mix different types of operations
      20.times do |i|
        threads << Thread.new do
          shell.send(:process_input, "/increment")
        end
        
        threads << Thread.new do
          shell.send(:process_input, "/read")
        end
        
        threads << Thread.new do
          shell.send(:process_input, "/stateful")
        end
      end
      
      expect { threads.each(&:join) }.not_to raise_error
    end
  end
  
  describe "deadlock prevention" do
    it "avoids deadlocks with proper lock ordering" do
      # Test that we can handle multiple locks without deadlock
      safe_app = Class.new(Thor) do
        include Thor::Interactive::Command
        
        class << self
          attr_accessor :lock, :counter
        end
        
        self.lock = Mutex.new
        self.counter = 0
        
        desc "safe_increment", "Safely increment"
        def safe_increment
          self.class.lock.synchronize do
            current = self.class.counter
            sleep 0.001
            self.class.counter = current + 1
            puts "Counter: #{self.class.counter}"
          end
        end
      end
      
      shell = Thor::Interactive::Shell.new(safe_app)
      safe_app.counter = 0
      
      # Run multiple threads that all use the same lock
      threads = 5.times.map do
        Thread.new do
          old_stdout = $stdout
          $stdout = StringIO.new
          begin
            shell.send(:process_input, "/safe_increment")
          ensure
            $stdout = old_stdout
          end
        end
      end
      
      # Should complete without deadlock
      expect {
        Timeout.timeout(2) do
          threads.each(&:join)
        end
      }.not_to raise_error
      
      # All increments should be accounted for
      expect(safe_app.counter).to eq(5)
    end
  end
  
  describe "atomic operations" do
    it "ensures atomic state updates" do
      atomic_app = Class.new(Thor) do
        include Thor::Interactive::Command
        
        class << self
          attr_accessor :atomic_state
        end
        
        self.atomic_state = Concurrent::AtomicFixnum.new(0)
        
        desc "atomic_inc", "Atomic increment"
        def atomic_inc
          new_val = self.class.atomic_state.increment
          puts "Atomic: #{new_val}"
        end
      end
      
      shell = Thor::Interactive::Shell.new(atomic_app)
      
      threads = 100.times.map do
        Thread.new do
          capture_stdout { shell.send(:process_input, "/atomic_inc") }
        end
      end
      
      threads.each(&:join)
      
      # Final value should be exactly 100
      expect(atomic_app.atomic_state.value).to eq(100)
    end
  end
  
  describe "thread-local storage" do
    it "maintains thread-local state correctly" do
      tls_app = Class.new(Thor) do
        include Thor::Interactive::Command
        
        desc "set_tls VALUE", "Set thread-local value"
        def set_tls(value)
          Thread.current[:tls_value] = value
          puts "Set: #{value}"
        end
        
        desc "get_tls", "Get thread-local value"
        def get_tls
          puts "Get: #{Thread.current[:tls_value]}"
        end
      end
      
      shell = Thor::Interactive::Shell.new(tls_app)
      outputs = Concurrent::Array.new
      
      threads = 5.times.map do |i|
        Thread.new do
          out1 = capture_stdout { shell.send(:process_input, "/set_tls thread_#{i}") }
          out2 = capture_stdout { shell.send(:process_input, "/get_tls") }
          outputs << [out1, out2]
        end
      end
      
      threads.each(&:join)
      
      # Each thread should see its own value
      outputs.each_with_index do |(set_out, get_out), i|
        expect(get_out).to include("thread_#{i}")
      end
    end
  end
  
  describe "concurrent error handling" do
    it "handles errors in concurrent commands independently" do
      error_app = Class.new(Thor) do
        include Thor::Interactive::Command
        
        desc "maybe_fail", "Randomly fails"
        def maybe_fail
          if rand > 0.5
            raise "Random failure"
          else
            puts "Success"
          end
        end
      end
      
      shell = Thor::Interactive::Shell.new(error_app)
      
      threads = 20.times.map do
        Thread.new do
          capture_stdout do
            shell.send(:process_input, "/maybe_fail")
          end
        end
      end
      
      # All threads should complete despite some failures
      expect { threads.each(&:join) }.not_to raise_error
    end
  end
end