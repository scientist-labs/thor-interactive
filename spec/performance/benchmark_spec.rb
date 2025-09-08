# frozen_string_literal: true

require "rspec-benchmark"
require "memory_profiler"
require "benchmark"

RSpec.describe "Performance Benchmarks", :performance do
  include RSpec::Benchmark::Matchers
  
  let(:test_app) do
    Class.new(Thor) do
      include Thor::Interactive::Command
      
      desc "echo MESSAGE", "Echo a message"
      def echo(message)
        puts message
      end
      
      desc "process", "Process data"
      def process
        @data ||= []
        @data << Time.now.to_f
        puts "Processed: #{@data.size}"
      end
      
      desc "calculate", "Do calculation"
      def calculate
        sum = (1..1000).reduce(:+)
        puts "Sum: #{sum}"
      end
    end
  end
  
  describe "command execution performance" do
    it "executes 1000 commands efficiently" do
      shell = Thor::Interactive::Shell.new(test_app)
      
      expect {
        1000.times do |i|
          shell.send(:process_input, "/echo test#{i}")
        end
      }.to perform_under(5).sec
    end
    
    it "handles rapid command entry" do
      shell = Thor::Interactive::Shell.new(test_app)
      
      expect {
        100.times do
          shell.send(:process_input, "/calculate")
        end
      }.to perform_under(1).sec
    end
    
    it "maintains consistent performance over time" do
      shell = Thor::Interactive::Shell.new(test_app)
      
      # Warm up
      10.times { shell.send(:process_input, "/process") }
      
      # Test performance doesn't degrade
      first_batch = ::Benchmark.realtime do
        100.times { shell.send(:process_input, "/process") }
      end
      
      second_batch = ::Benchmark.realtime do
        100.times { shell.send(:process_input, "/process") }
      end
      
      # Second batch should not be significantly slower
      expect(second_batch).to be_within(0.2).of(first_batch)
    end
  end
  
  describe "memory usage" do
    it "maintains reasonable memory usage during long session" do
      shell = Thor::Interactive::Shell.new(test_app)
      
      report = MemoryProfiler.report do
        500.times do |i|
          shell.send(:process_input, "/echo message_#{i}")
        end
      end
      
      # Memory should stay under 10MB for basic operations
      expect(report.total_allocated_memsize).to be < 10_000_000
    end
    
    it "doesn't leak memory with stateful commands" do
      shell = Thor::Interactive::Shell.new(test_app)
      
      # Baseline memory
      GC.start
      baseline = `ps -o rss= -p #{Process.pid}`.to_i
      
      # Run many stateful commands
      1000.times do
        shell.send(:process_input, "/process")
      end
      
      GC.start
      final = `ps -o rss= -p #{Process.pid}`.to_i
      
      # Memory growth should be minimal (< 5MB)
      growth_mb = (final - baseline) / 1024.0
      expect(growth_mb).to be < 5
    end
    
    it "properly garbage collects completed commands" do
      shell = Thor::Interactive::Shell.new(test_app)
      
      # Track object allocations
      before_count = ObjectSpace.count_objects[:T_STRING]
      
      100.times do |i|
        shell.send(:process_input, "/echo string_#{i}")
      end
      
      GC.start
      after_count = ObjectSpace.count_objects[:T_STRING]
      
      # String objects should be garbage collected
      growth = after_count - before_count
      expect(growth).to be < 200  # Allow some growth but not 100 strings per command
    end
  end
  
  describe "large input/output handling" do
    let(:large_output_app) do
      Class.new(Thor) do
        include Thor::Interactive::Command
        
        desc "large_output", "Generate large output"
        def large_output
          10000.times { |i| puts "Line #{i}: " + "x" * 100 }
        end
        
        desc "process_large INPUT", "Process large input"
        def process_large(input)
          puts "Processed #{input.length} characters"
        end
      end
    end
    
    it "handles large outputs efficiently" do
      shell = Thor::Interactive::Shell.new(large_output_app)
      
      expect {
        capture_stdout do
          shell.send(:process_input, "/large_output")
        end
      }.to perform_under(1).sec
    end
    
    it "processes large inputs without blocking" do
      shell = Thor::Interactive::Shell.new(large_output_app)
      large_input = "x" * 10000
      
      expect {
        shell.send(:process_input, "/process_large #{large_input}")
      }.to perform_under(0.1).sec
    end
  end
  
  describe "completion performance" do
    let(:many_commands_app) do
      Class.new(Thor) do
        include Thor::Interactive::Command
        
        # Generate many commands for completion testing
        100.times do |i|
          desc "command_#{i}", "Command #{i}"
          define_method("command_#{i}") { puts "Command #{i}" }
        end
      end
    end
    
    it "completes commands quickly even with many options" do
      shell = Thor::Interactive::Shell.new(many_commands_app)
      
      expect {
        100.times do
          shell.send(:complete_input, "com", "")
        end
      }.to perform_under(0.5).sec
    end
    
    it "caches completion results efficiently" do
      shell = Thor::Interactive::Shell.new(many_commands_app)
      
      # First completion might be slower
      first = ::Benchmark.realtime do
        shell.send(:complete_input, "command_", "")
      end
      
      # Subsequent completions should be faster
      second = ::Benchmark.realtime do
        10.times { shell.send(:complete_input, "command_", "") }
      end
      
      expect(second / 10).to be < (first * 0.5)  # At least 2x faster
    end
  end
  
  describe "history management performance" do
    it "handles large history efficiently" do
      with_temp_history_file do |path|
        shell = Thor::Interactive::Shell.new(test_app, history_file: path)
        
        # Add many items to history
        expect {
          1000.times do |i|
            Reline::HISTORY.push("command_#{i}")
          end
          shell.send(:save_history)
        }.to perform_under(0.5).sec
      end
    end
    
    it "loads large history files quickly" do
      with_temp_history_file do |path|
        # Create large history file
        File.open(path, "w") do |f|
          5000.times { |i| f.puts "command_#{i}" }
        end
        
        expect {
          Thor::Interactive::Shell.new(test_app, history_file: path)
        }.to perform_under(0.5).sec
      end
    end
  end
  
  describe "stress testing" do
    it "remains stable under rapid mixed operations" do
      shell = Thor::Interactive::Shell.new(test_app)
      
      expect {
        100.times do
          # Mix of different operations
          shell.send(:process_input, "/echo test")
          shell.send(:complete_input, "ec", "")
          shell.send(:process_input, "/calculate")
          shell.send(:process_input, "help")
          shell.send(:process_input, "/process")
        end
      }.not_to raise_error
    end
    
    it "handles malformed input gracefully under load" do
      shell = Thor::Interactive::Shell.new(test_app)
      
      expect {
        100.times do
          shell.send(:process_input, "/echo \"unclosed quote")
          shell.send(:process_input, "/unknown_command")
          shell.send(:process_input, "///multiple/slashes")
          shell.send(:process_input, "")
          shell.send(:process_input, "   ")
        end
      }.to perform_under(1).sec
    end
  end
end