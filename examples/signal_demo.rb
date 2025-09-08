#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "thor/interactive"

class SignalDemo < Thor
  include Thor::Interactive::Command
  
  configure_interactive(
    prompt: "signal> ",
    ctrl_c_behavior: :clear_prompt,  # Default
    double_ctrl_c_timeout: 0.5        # 500ms window for double Ctrl-C
  )
  
  desc "slow", "Simulate a slow command"
  def slow
    puts "Starting slow operation..."
    5.times do |i|
      puts "Step #{i + 1}/5"
      sleep(1)
    end
    puts "Done!"
  rescue Interrupt
    puts "\nOperation cancelled!"
  end
  
  desc "loop", "Run an infinite loop (test Ctrl-C)"
  def loop
    puts "Starting infinite loop (press Ctrl-C to stop)..."
    counter = 0
    while true
      print "\rCounter: #{counter}"
      counter += 1
      sleep(0.1)
    end
  rescue Interrupt
    puts "\nLoop stopped at #{counter}"
  end
  
  desc "input", "Test input with special text"
  def input
    puts "Type something with Ctrl chars:"
    puts "  - Ctrl-C to clear and start over"
    puts "  - Ctrl-D to cancel"
    puts "  - Enter to submit"
    
    print "input> "
    begin
      text = $stdin.gets
      if text
        puts "You entered: #{text.inspect}"
      else
        puts "Cancelled with Ctrl-D"
      end
    rescue Interrupt
      puts "\nInterrupted - input cancelled"
    end
  end
  
  desc "behaviors", "Demo different Ctrl-C behaviors"
  def behaviors
    puts "\n=== Ctrl-C Behavior Options ==="
    puts
    puts "1. :clear_prompt (default)"
    puts "   - Shows ^C and hint message"
    puts "   - Clear and friendly"
    
    puts "\n2. :show_help"
    puts "   - Shows help reminder"
    puts "   - Good for new users"
    
    puts "\n3. :silent"
    puts "   - Just clears the line"
    puts "   - Minimal interruption"
    
    puts "\nYou can configure with:"
    puts "  configure_interactive(ctrl_c_behavior: :show_help)"
  end
  
  desc "test_clear", "Test with clear_prompt behavior"
  def test_clear
    puts "Starting new shell with :clear_prompt behavior"
    puts "Try pressing Ctrl-C..."
    puts
    
    SignalDemo.new.interactive
  end
  
  desc "test_help", "Test with show_help behavior"
  def test_help
    puts "Starting new shell with :show_help behavior"
    puts "Try pressing Ctrl-C..."
    puts
    
    test_app = Class.new(Thor) do
      include Thor::Interactive::Command
      configure_interactive(
        prompt: "help> ",
        ctrl_c_behavior: :show_help
      )
      
      desc "test", "Test command"
      def test
        puts "Test executed"
      end
    end
    
    test_app.new.interactive
  end
  
  desc "test_silent", "Test with silent behavior"
  def test_silent
    puts "Starting new shell with :silent behavior"
    puts "Try pressing Ctrl-C..."
    puts
    
    test_app = Class.new(Thor) do
      include Thor::Interactive::Command
      configure_interactive(
        prompt: "silent> ",
        ctrl_c_behavior: :silent
      )
      
      desc "test", "Test command"
      def test
        puts "Test executed"
      end
    end
    
    test_app.new.interactive
  end
  
  desc "help_signals", "Explain signal handling"
  def help_signals
    puts <<~HELP
    
    === Signal Handling in thor-interactive ===
    
    CTRL-C (SIGINT):
      Single Press:
        - Clears current input line
        - Shows hint about double Ctrl-C
        - Returns to fresh prompt
        
      Double Press (within 500ms):
        - Exits the interactive shell
        - Same as typing 'exit'
    
    CTRL-D (EOF):
      - Exits immediately
      - Standard Unix EOF behavior
      - Same as typing 'exit'
    
    EXIT COMMANDS:
      - exit
      - quit  
      - q
      - /exit, /quit, /q (with slash)
    
    CONFIGURATION:
      configure_interactive(
        ctrl_c_behavior: :clear_prompt,  # or :show_help, :silent
        double_ctrl_c_timeout: 0.5        # seconds
      )
    
    BEHAVIOR OPTIONS:
      :clear_prompt (default)
        Shows "^C" and hint message
        
      :show_help
        Shows help reminder on Ctrl-C
        
      :silent
        Just clears the line, no message
    
    WHY THIS DESIGN?
      - Matches behavior of Python, Node.js REPLs
      - Prevents accidental exit
      - Clear feedback to user
      - Configurable for different preferences
    
    HELP
  end
  
  default_task :help_signals
end

if __FILE__ == $0
  puts "Signal Handling Demo"
  puts "==================="
  puts
  puts "Try these:"
  puts "  1. Press Ctrl-C once (clears prompt)"
  puts "  2. Press Ctrl-C twice quickly (exits)"
  puts "  3. Press Ctrl-D (exits immediately)"
  puts "  4. Type 'exit', 'quit', or 'q' (exits)"
  puts
  puts "Starting interactive shell..."
  puts
  
  SignalDemo.new.interactive
end