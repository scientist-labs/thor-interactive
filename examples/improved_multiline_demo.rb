#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "thor/interactive"

class ImprovedMultilineDemo < Thor
  include Thor::Interactive::Command
  
  configure_interactive(
    ui_mode: :advanced,
    input_mode: :multiline,
    auto_multiline: true,
    prompt: "demo> "
  )
  
  desc "smart", "Demo smart multi-line input"
  def smart
    puts "\n=== Smart Multi-line Input Demo ==="
    puts "\nThe input will automatically detect when you need multiple lines:"
    puts "  • Unclosed brackets, quotes → continues automatically"
    puts "  • Keywords (def, class, if) → continues automatically"  
    puts "  • Empty line → submits the input"
    puts "  • Ctrl+D → force submit at any time"
    puts "\nTry entering some Ruby code:\n"
    
    smart_input = Thor::Interactive::UI::Components::SmartInput.new
    
    result = smart_input.read("ruby> ")
    
    if result
      puts "\n--- You entered: ---"
      puts result
      puts "--- End ---"
      puts "\nLines: #{result.lines.count}"
    else
      puts "\nNo input provided"
    end
  end
  
  desc "simple", "Demo simple multi-line with visual cues"
  def simple
    puts "\n=== Simple Multi-line Input ==="
    puts "\nInstructions:"
    puts "  • Enter text line by line"
    puts "  • Press Enter on empty line to submit"
    puts "  • Press Ctrl+D to force submit"
    puts "\nEnter your text:\n"
    
    result = Thor::Interactive::UI::Components::SimpleMultilineInput.read(
      "text> ",
      hint: "[Multi-line mode - Empty line to submit]",
      show_count: true,
      continuation: "     "
    )
    
    if result
      puts "\n--- Result: ---"
      puts result
      puts "--- End ---"
    else
      puts "\nCancelled"
    end
  end
  
  desc "continuation", "Demo line continuation with backslash"
  def continuation
    puts "\n=== Line Continuation Demo ==="
    puts "\nUse \\ at the end of a line to continue:"
    puts "Example: long command \\"
    puts "         with multiple \\"
    puts "         parts"
    puts "\nTry it:\n"
    
    shell = Thor::Interactive::UI::EnhancedShell.new(self.class)
    input = shell.send(:read_continuation_lines)
    
    puts "\nJoined result: #{input}"
  end
  
  desc "json", "Enter JSON with smart detection"
  def json
    require 'json'
    
    puts "\n=== JSON Input with Smart Detection ==="
    puts "\nStart typing JSON - brackets will auto-continue:\n"
    
    smart = Thor::Interactive::UI::Components::SmartInput.new
    result = smart.read("json> ")
    
    if result
      begin
        parsed = JSON.parse(result)
        puts "\n✓ Valid JSON!"
        puts JSON.pretty_generate(parsed)
      rescue JSON::ParserError => e
        puts "\n✗ Invalid JSON: #{e.message}"
        puts "\nRaw input:"
        puts result
      end
    end
  end
  
  desc "code", "Enter code with auto-detection"
  def code
    puts "\n=== Code Entry with Auto-detection ==="
    puts "\nKeywords like 'def', 'class', 'if' will auto-continue:\n"
    
    smart = Thor::Interactive::UI::Components::SmartInput.new
    result = smart.read("code> ")
    
    if result
      puts "\n--- Code: ---"
      lines = result.lines
      lines.each_with_index do |line, i|
        printf "%3d | %s", i + 1, line
      end
      puts "--- End ---"
      
      # Try syntax check
      begin
        eval("BEGIN { return true }\n#{result}")
        puts "\n✓ Valid Ruby syntax"
      rescue SyntaxError => e
        puts "\n✗ Syntax error: #{e.message.lines.first}"
      end
    end
  end
  
  desc "compare", "Compare all input methods"
  def compare
    puts "\n=== Input Method Comparison ==="
    
    puts "\n1. Standard (current) - backslash continuation:"
    puts "   Type 'hello \\' and press Enter to continue on next line"
    print "   > "
    standard = $stdin.gets.chomp
    if standard.end_with?("\\")
      print "   ... "
      standard = standard.chomp("\\") + " " + $stdin.gets.chomp
    end
    puts "   Result: '#{standard}'"
    
    puts "\n2. Smart detection - automatic continuation:"
    puts "   Type 'def hello' and press Enter (will auto-continue)"
    smart = Thor::Interactive::UI::Components::SmartInput.new
    smart_result = smart.read("   > ")
    puts "   Result: '#{smart_result}'"
    
    puts "\n3. Simple multi-line - empty line to submit:"
    puts "   Type multiple lines, empty line submits"
    simple_result = Thor::Interactive::UI::Components::SimpleMultilineInput.read(
      "   > ",
      continuation: "   ... "
    )
    puts "   Result: '#{simple_result}'"
    
    puts "\n=== Comparison Complete ==="
  end
  
  desc "help_multiline", "Show all multi-line input options"
  def help_multiline
    puts <<~HELP
    
    === Multi-line Input Options in thor-interactive ===
    
    1. BACKSLASH CONTINUATION (Current Default)
       - End line with \\ to continue
       - Simple and explicit
       - Works everywhere
       
       Example:
         > long command \\
         ... with continuation
    
    2. SMART DETECTION (New Option)
       - Automatically detects when to continue
       - Checks for unclosed brackets/quotes
       - Recognizes block keywords (def, class, if)
       - Empty line or Ctrl+D to submit
       
       Example:
         > def hello
         ...   puts "world"  
         ... end
    
    3. SIMPLE MULTI-LINE (Alternative)
       - Always in multi-line mode
       - Empty line to submit
       - Shows line count
       - Good for text entry
       
       Example:
         > First line
         ... Second line
         ... [2 lines]
         ... (empty line to submit)
    
    4. KEYBOARD SHORTCUTS (Future)
       - Would need terminal raw mode
       - Alt+Enter or Ctrl+J for newline
       - More complex to implement
       - Better for advanced users
    
    CONFIGURATION OPTIONS:
    
      configure_interactive(
        input_mode: :multiline,
        auto_multiline: true,      # Enable smart detection
        multiline_threshold: 2     # Empty lines to submit
      )
    
    HELP
  end
  
  default_task :help_multiline
end

if __FILE__ == $0
  # Enable UI
  Thor::Interactive::UI.configure do |config|
    config.enable!
  end
  
  ImprovedMultilineDemo.start(ARGV)
end