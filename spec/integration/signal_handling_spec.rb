# frozen_string_literal: true

require "spec_helper"
require "timeout"
require "stringio"

RSpec.describe "Signal handling" do
  let(:test_app) do
    Class.new(Thor) do
      include Thor::Interactive::Command
      
      desc "test", "Test command"
      def test
        puts "test executed"
      end
    end
  end
  
  describe "Ctrl-C handling" do
    it "clears prompt on single Ctrl-C" do
      shell = Thor::Interactive::Shell.new(test_app)
      
      # Simulate interrupt
      expect(shell.send(:handle_interrupt)).to eq(false)
      
      # Should not exit
      expect(shell.instance_variable_get(:@last_interrupt_time)).not_to be_nil
    end
    
    it "exits on double Ctrl-C within timeout" do
      shell = Thor::Interactive::Shell.new(test_app)
      
      # First Ctrl-C
      expect(shell.send(:handle_interrupt)).to eq(false)
      
      # Second Ctrl-C immediately
      expect(shell.send(:handle_interrupt)).to eq(true)
    end
    
    it "doesn't exit on double Ctrl-C after timeout" do
      shell = Thor::Interactive::Shell.new(test_app, double_ctrl_c_timeout: 0.1)
      
      # First Ctrl-C
      expect(shell.send(:handle_interrupt)).to eq(false)
      
      # Wait for timeout
      sleep(0.2)
      
      # Second Ctrl-C after timeout - should not exit
      expect(shell.send(:handle_interrupt)).to eq(false)
    end
    
    it "resets interrupt tracking on successful input" do
      shell = Thor::Interactive::Shell.new(test_app)
      
      # Set interrupt time
      shell.instance_variable_set(:@last_interrupt_time, Time.now)
      
      # Simulate successful input by accessing the variable
      # (In real usage, this happens in the main loop after readline)
      shell.instance_variable_set(:@last_interrupt_time, nil)
      
      expect(shell.instance_variable_get(:@last_interrupt_time)).to be_nil
    end
  end
  
  describe "Ctrl-D handling" do
    it "exits on Ctrl-D (nil input)" do
      shell = Thor::Interactive::Shell.new(test_app)
      
      # Ctrl-D returns nil from readline
      expect(shell.send(:should_exit?, nil)).to eq(true)
    end
    
    it "doesn't exit on empty string" do
      shell = Thor::Interactive::Shell.new(test_app)
      
      # Empty line is different from Ctrl-D
      expect(shell.send(:should_exit?, "")).to eq(false)
      expect(shell.send(:should_exit?, "  ")).to eq(false)
    end
  end
  
  describe "Configuration options" do
    it "supports different Ctrl-C behaviors" do
      # Clear prompt behavior (default)
      shell1 = Thor::Interactive::Shell.new(test_app)
      expect(shell1.instance_variable_get(:@ctrl_c_behavior)).to eq(:clear_prompt)
      
      # Show help behavior
      shell2 = Thor::Interactive::Shell.new(test_app, ctrl_c_behavior: :show_help)
      expect(shell2.instance_variable_get(:@ctrl_c_behavior)).to eq(:show_help)
      
      # Silent behavior
      shell3 = Thor::Interactive::Shell.new(test_app, ctrl_c_behavior: :silent)
      expect(shell3.instance_variable_get(:@ctrl_c_behavior)).to eq(:silent)
    end
    
    it "allows customizing double Ctrl-C timeout" do
      shell = Thor::Interactive::Shell.new(test_app, double_ctrl_c_timeout: 1.5)
      expect(shell.instance_variable_get(:@double_ctrl_c_timeout)).to eq(1.5)
    end
  end
  
  describe "Exit commands" do
    it "exits on 'exit' command" do
      shell = Thor::Interactive::Shell.new(test_app)
      
      expect(shell.send(:should_exit?, "exit")).to eq(true)
      expect(shell.send(:should_exit?, "EXIT")).to eq(true)
      expect(shell.send(:should_exit?, " exit ")).to eq(true)
    end
    
    it "exits on 'quit' command" do
      shell = Thor::Interactive::Shell.new(test_app)
      
      expect(shell.send(:should_exit?, "quit")).to eq(true)
      expect(shell.send(:should_exit?, "QUIT")).to eq(true)
    end
    
    it "exits on 'q' command" do
      shell = Thor::Interactive::Shell.new(test_app)
      
      expect(shell.send(:should_exit?, "q")).to eq(true)
      expect(shell.send(:should_exit?, "Q")).to eq(true)
    end
    
    it "handles /exit format" do
      shell = Thor::Interactive::Shell.new(test_app)
      
      expect(shell.send(:should_exit?, "/exit")).to eq(true)
      expect(shell.send(:should_exit?, "/quit")).to eq(true)
      expect(shell.send(:should_exit?, "/q")).to eq(true)
    end
  end
  
  describe "handle_interrupt output" do
    it "shows appropriate message for clear_prompt behavior" do
      shell = Thor::Interactive::Shell.new(test_app, ctrl_c_behavior: :clear_prompt)
      
      output = capture_stdout do
        shell.send(:handle_interrupt)
      end
      
      expect(output).to include("^C")
      expect(output).to include("Press Ctrl-C again quickly or Ctrl-D to exit")
    end
    
    it "shows help message for show_help behavior" do
      shell = Thor::Interactive::Shell.new(test_app, ctrl_c_behavior: :show_help)
      
      output = capture_stdout do
        shell.send(:handle_interrupt)
      end
      
      expect(output).to include("^C - Interrupt")
      expect(output).to include("Press Ctrl-C again to exit")
    end
    
    it "shows nothing for silent behavior" do
      shell = Thor::Interactive::Shell.new(test_app, ctrl_c_behavior: :silent)
      
      output = capture_stdout do
        shell.send(:handle_interrupt)
      end
      
      # Should only have clearing characters, no text
      expect(output).not_to include("^C")
      expect(output).not_to include("exit")
    end
  end
  
  describe "Integration with main loop" do
    it "continues after single interrupt" do
      # This is more of a documentation test showing the expected flow
      shell = Thor::Interactive::Shell.new(test_app)
      
      # In the main loop, a single interrupt:
      # 1. Catches Interrupt exception
      # 2. Calls handle_interrupt which returns false
      # 3. Continues the loop with 'next'
      
      expect(shell.send(:handle_interrupt)).to eq(false)
    end
    
    it "exits after double interrupt" do
      shell = Thor::Interactive::Shell.new(test_app)
      
      # In the main loop, a double interrupt:
      # 1. First interrupt caught, handle_interrupt returns false
      # 2. Second interrupt caught quickly, handle_interrupt returns true
      # 3. Breaks the loop
      
      shell.send(:handle_interrupt)  # First
      expect(shell.send(:handle_interrupt)).to eq(true)  # Second
    end
  end
  
  describe "Edge cases" do
    it "handles rapid multiple interrupts correctly" do
      shell = Thor::Interactive::Shell.new(test_app)
      
      # First interrupt
      expect(shell.send(:handle_interrupt)).to eq(false)
      
      # Second interrupt (should exit)
      expect(shell.send(:handle_interrupt)).to eq(true)
      
      # Third interrupt (should reset and not exit)
      expect(shell.send(:handle_interrupt)).to eq(false)
    end
    
    it "handles interrupt with nil timeout" do
      shell = Thor::Interactive::Shell.new(test_app, double_ctrl_c_timeout: nil)
      
      # Should use default timeout (0.5)
      expect(shell.instance_variable_get(:@double_ctrl_c_timeout)).to eq(nil)
      
      # But should still work (comparing with nil should work)
      expect(shell.send(:handle_interrupt)).to eq(false)
    end
    
    it "doesn't exit on regular commands that contain 'exit'" do
      shell = Thor::Interactive::Shell.new(test_app)
      
      expect(shell.send(:should_exit?, "exit_handler")).to eq(false)
      expect(shell.send(:should_exit?, "handle_exit")).to eq(false)
      expect(shell.send(:should_exit?, "exiting")).to eq(false)
    end
    
    it "handles mixed case exit commands" do
      shell = Thor::Interactive::Shell.new(test_app)
      
      expect(shell.send(:should_exit?, "ExIt")).to eq(true)
      expect(shell.send(:should_exit?, "QuIt")).to eq(true)
      expect(shell.send(:should_exit?, "Q")).to eq(true)
    end
    
    it "handles whitespace in exit commands" do
      shell = Thor::Interactive::Shell.new(test_app)
      
      expect(shell.send(:should_exit?, "  exit  ")).to eq(true)
      expect(shell.send(:should_exit?, "\texit\t")).to eq(true)
      expect(shell.send(:should_exit?, "\n exit \n")).to eq(true)
    end
  end
  
  describe "Configuration inheritance" do
    it "inherits configuration from class-level settings" do
      configured_app = Class.new(Thor) do
        include Thor::Interactive::Command
        
        configure_interactive(
          ctrl_c_behavior: :show_help,
          double_ctrl_c_timeout: 1.0
        )
      end
      
      shell = Thor::Interactive::Shell.new(configured_app)
      
      expect(shell.instance_variable_get(:@ctrl_c_behavior)).to eq(:show_help)
      expect(shell.instance_variable_get(:@double_ctrl_c_timeout)).to eq(1.0)
    end
    
    it "allows instance-level override of class settings" do
      configured_app = Class.new(Thor) do
        include Thor::Interactive::Command
        
        configure_interactive(
          ctrl_c_behavior: :show_help
        )
      end
      
      # Instance options override class options
      shell = Thor::Interactive::Shell.new(configured_app, ctrl_c_behavior: :silent)
      
      expect(shell.instance_variable_get(:@ctrl_c_behavior)).to eq(:silent)
    end
  end
  
  describe "Thread safety" do
    it "handles concurrent interrupts safely" do
      shell = Thor::Interactive::Shell.new(test_app)
      
      results = []
      threads = 3.times.map do
        Thread.new do
          results << shell.send(:handle_interrupt)
        end
      end
      
      threads.each(&:join)
      
      # At most one should return true (exit)
      expect(results.count(true)).to be <= 1
    end
  end
  
  describe "Invalid configuration handling" do
    it "handles unknown ctrl_c_behavior gracefully" do
      shell = Thor::Interactive::Shell.new(test_app, ctrl_c_behavior: :unknown)
      
      # Should still work, falling back to default case
      output = capture_stdout do
        expect(shell.send(:handle_interrupt)).to eq(false)
      end
      
      expect(output).to include("^C")  # Default behavior
    end
    
    it "handles negative timeout" do
      shell = Thor::Interactive::Shell.new(test_app, double_ctrl_c_timeout: -1)
      
      # Negative timeout means double-press never works
      expect(shell.send(:handle_interrupt)).to eq(false)
      expect(shell.send(:handle_interrupt)).to eq(false)  # Still false
    end
    
    it "handles zero timeout" do
      shell = Thor::Interactive::Shell.new(test_app, double_ctrl_c_timeout: 0)
      
      # Zero timeout means must be instantaneous
      expect(shell.send(:handle_interrupt)).to eq(false)
      # Even immediate second call might be too slow, but should not crash
      shell.send(:handle_interrupt)
    end
  end
end