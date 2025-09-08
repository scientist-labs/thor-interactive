#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "thor/interactive"

class EdgeCaseTest < Thor
  include Thor::Interactive::Command
  
  configure_interactive(
    prompt: "test> ",
    default_handler: ->(input, instance) { 
      puts "DEFAULT HANDLER: '#{input}'"
    }
  )
  
  desc "topics [FILTER]", "List topics"
  option :summarize, type: :boolean, desc: "Summarize topics"
  option :format, type: :string, desc: "Output format"
  def topics(filter = nil)
    puts "TOPICS COMMAND:"
    puts "  Filter: #{filter.inspect}"
    puts "  Options: #{options.to_h.inspect}"
  end
  
  desc "echo TEXT", "Echo text"
  def echo(text)
    puts "ECHO: '#{text}'"
  end
  
  desc "test", "Run edge case tests"
  def test
    puts "\n=== Edge Case Tests ==="
    
    puts "\n1. Unknown option:"
    puts "   Input: /topics --unknown-option"
    process_input("/topics --unknown-option")
    
    puts "\n2. Unknown option with value:"
    puts "   Input: /topics --unknown-option value"
    process_input("/topics --unknown-option value")
    
    puts "\n3. Mixed text and option-like strings:"
    puts "   Input: /topics The start of a string --option the rest"
    process_input("/topics The start of a string --option the rest")
    
    puts "\n4. Valid option mixed with text:"
    puts "   Input: /topics Some text --summarize more text"
    process_input("/topics Some text --summarize more text")
    
    puts "\n5. Option-like text in echo command (no options defined):"
    puts "   Input: /echo This has --what-looks-like an option"
    process_input("/echo This has --what-looks-like an option")
    
    puts "\n6. Real option after text:"
    puts "   Input: /topics AI and ML --format json"
    process_input("/topics AI and ML --format json")
    
    puts "\n=== End Tests ==="
  end
  
  private
  
  def process_input(input)
    # Simulate what the shell does
    if input.start_with?('/')
      send(:handle_slash_command, input[1..-1])
    else
      @default_handler.call(input, self)
    end
  rescue => e
    puts "   ERROR: #{e.message}"
  end
  
  def handle_slash_command(command_input)
    parts = command_input.split(/\s+/, 2)
    command = parts[0]
    args = parts[1] || ""
    
    if command == "topics"
      # Parse with shellwords
      require 'shellwords'
      parsed = Shellwords.split(args) rescue args.split(/\s+/)
      invoke("topics", parsed)
    elsif command == "echo"
      echo(args)
    end
  rescue => e
    puts "   ERROR: #{e.message}"
  end
end

if __FILE__ == $0
  puts "Edge Case Testing"
  puts "================="
  
  # Create instance and run tests
  app = EdgeCaseTest.new
  app.test
  
  puts "\nInteractive mode - try these:"
  puts "  /topics --unknown-option"
  puts "  /topics The start --option the rest"
  puts
  
  app.interactive
end