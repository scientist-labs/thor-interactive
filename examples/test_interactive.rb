#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to verify interactive functionality
# This simulates what would happen in interactive mode

require_relative "../lib/thor/interactive"

class TestApp < Thor
  include Thor::Interactive::Command

  configure_interactive(
    prompt: "test> ",
    default_handler: proc do |input, instance|
      puts "Default handler got: #{input}"
    end
  )

  class_variable_set(:@@counter, 0)

  desc "count", "Increment and show counter"
  def count
    @@counter += 1
    puts "Count: #{@@counter}"
  end

  desc "hello NAME", "Say hello"
  def hello(name)
    puts "Hello #{name}!"
  end
end

# Test normal CLI mode
puts "=== Testing Normal CLI Mode ==="
puts "Running: hello Alice"
TestApp.start(["hello", "Alice"])
puts "\nRunning: count (twice - should both be 1)"
TestApp.start(["count"])
TestApp.start(["count"])

puts "\n=== Testing Interactive Shell Creation ==="
shell = Thor::Interactive::Shell.new(TestApp)
puts "Shell created successfully with Thor class: #{shell.thor_class}"
puts "Shell has persistent Thor instance: #{shell.thor_instance.class}"

puts "\n=== Testing Command Recognition ==="
# Test if commands are recognized
test_commands = %w[hello count help exit]
test_commands.each do |cmd|
  recognized = shell.send(:thor_command?, cmd)
  puts "Command '#{cmd}': #{recognized ? 'recognized' : 'not recognized'}"
end

puts "\n=== Testing Completion ==="
completions = shell.send(:complete_commands, "h")
puts "Completions for 'h': #{completions}"

puts "\n=== Interactive mode ready! ==="
puts "To test interactively, run: ruby examples/sample_app.rb interactive"
puts "Then try commands like:"
puts "  count (multiple times to see state persistence)"
puts "  add item1"
puts "  add item2" 
puts "  list"
puts "  hello Alice"
puts "  help"
puts "  exit"