#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/thor/interactive"

# Example app that allows nested interactive sessions
class NestedApp < Thor
  include Thor::Interactive::Command

  configure_interactive(
    prompt: "nested> ",
    allow_nested: true,  # Allow nested interactive sessions
    nested_prompt_format: "[L%d] %s"  # Custom format for nested prompts
  )

  desc "hello NAME", "Say hello"
  def hello(name)
    puts "Hello #{name}!"
  end

  desc "demo", "Show nesting demo info"
  def demo
    level = ENV['THOR_INTERACTIVE_LEVEL']
    puts "Current nesting level: #{level || 'not in interactive mode'}"
    puts "Try running 'interactive' to see nested sessions!"
  end

  desc "status", "Show session status"
  def status
    if ENV['THOR_INTERACTIVE_SESSION']
      level = ENV['THOR_INTERACTIVE_LEVEL'].to_i
      puts "In interactive session - Level #{level}"
    else
      puts "Not in interactive session"
    end
  end
end

# Example app that prevents nested sessions (default behavior)
class SafeApp < Thor
  include Thor::Interactive::Command

  configure_interactive(
    prompt: "safe> ",
    allow_nested: false  # This is the default, but being explicit
  )

  desc "hello NAME", "Say hello"
  def hello(name)
    puts "Hello #{name}!"
  end

  desc "demo", "Show nesting prevention"
  def demo
    puts "This app prevents nested sessions."
    puts "Try running 'interactive' to see the protection!"
  end
end

if __FILE__ == $0
  puts "=== Nested Interactive Sessions Demo ==="
  puts
  puts "1. NestedApp - allows nested sessions:"
  puts "   ruby nested_example.rb nested"
  puts 
  puts "2. SafeApp - prevents nested sessions:"
  puts "   ruby nested_example.rb safe"
  puts
  
  case ARGV[0]
  when "nested"
    ARGV.shift
    NestedApp.start(ARGV)
  when "safe" 
    ARGV.shift
    SafeApp.start(ARGV)
  else
    puts "Usage: ruby nested_example.rb [nested|safe] [command]"
  end
end