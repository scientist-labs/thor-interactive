#!/usr/bin/env ruby
# frozen_string_literal: true

# TUI Demo - demonstrates the ratatui_ruby-powered TUI mode
#
# Usage:
#   ruby examples/tui_demo.rb interactive
#   ruby examples/tui_demo.rb interactive --theme dark
#
# Key bindings:
#   Enter         - Submit input
#   Shift+Enter   - New line (multi-line input)
#   Alt+Enter     - New line (alternative)
#   Tab           - Auto-complete commands
#   Ctrl+C        - Clear input / double-tap to exit
#   Ctrl+D        - Exit
#   PageUp/Down   - Scroll output
#   Escape        - Clear input / dismiss completions
#
# Requires: gem install ratatui_ruby

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "thor"
require "thor/interactive"

class TuiDemo < Thor
  include Thor::Interactive::Command

  configure_interactive(
    ui_mode: :tui,
    prompt: "demo> ",
    # theme: :dark,  # Try: :default, :dark, :light, :minimal
    status_bar: {
      left: ->(instance) { " TUI Demo" },
      right: ->(instance) { " commands: #{instance.class.tasks.count} " }
    },
    # Custom spinner messages (optional - defaults are fun too)
    spinner_messages: ["Thinking", "Brewing", "Crunching", "Vibing", "Noodling"]
  )

  desc "hello", "Say hello"
  def hello
    puts "Hello from TUI mode!"
  end

  desc "greet NAME", "Greet someone by name"
  def greet(name)
    puts "Hello, #{name}! Welcome to the TUI demo."
  end

  desc "count N", "Count from 1 to N"
  def count(n)
    n.to_i.times do |i|
      puts "#{i + 1}..."
      sleep(0.1) # Slow enough to see the spinner
    end
    puts "Done counting!"
  end

  desc "status", "Show current status"
  def status
    puts "TUI Demo Status:"
    puts "  Session: active"
    puts "  Mode: TUI (ratatui_ruby)"
    puts "  Theme: #{self.class.interactive_options[:theme] || :default}"
    puts "  Commands available: #{self.class.tasks.keys.join(", ")}"
  end

  desc "error_demo", "Demonstrate error handling"
  def error_demo
    puts "About to raise an error..."
    raise "This is a demo error to show error handling"
  end

  desc "slow", "Demonstrate spinner with a slow command"
  def slow
    puts "Starting slow operation..."
    sleep(3)
    puts "Slow operation complete!"
  end

  desc "multiline", "Print multiple lines of output"
  def multiline
    puts "Line 1: This is a multi-line output demo"
    puts "Line 2: Each line appears in the output buffer"
    puts "Line 3: You can scroll up/down with PageUp/PageDown"
    puts "Line 4: The output persists between commands"
    puts "Line 5: End of demo output"
  end
end

TuiDemo.start(ARGV)
