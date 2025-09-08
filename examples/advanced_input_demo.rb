#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "thor/interactive"
require_relative "../lib/thor/interactive/ui/components/advanced_input"

class AdvancedInputDemo < Thor
  include Thor::Interactive::Command
  
  desc "test", "Test the advanced multi-line input"
  def test
    puts "\n=== Advanced Multi-line Input Test ==="
    puts "\nKey bindings:"
    puts "  Alt+Enter or Ctrl+J : Insert new line"
    puts "  Enter              : Submit (smart detection)"
    puts "  Escape or Ctrl+C   : Cancel"
    puts "  Tab                : Indent"
    puts "  Ctrl+K             : Kill rest of line"
    puts "  Ctrl+U             : Clear line"
    puts "  Ctrl+W             : Delete word"
    puts "\nSmart newline detection:"
    puts "  - Unclosed brackets/quotes → auto-continue"
    puts "  - Keywords (def, class, if) → auto-continue"
    puts "  - Indented lines → auto-continue"
    puts "\nTry it out:\n"
    
    input = Thor::Interactive::UI::Components::AdvancedInput.new(
      prompt: "input> ",
      continuation: "  ... ",
      show_line_numbers: true,
      syntax_highlighting: true,
      smart_newline: true,
      auto_indent: true
    )
    
    result = input.read_multiline
    
    if result
      puts "\n\nYou entered:"
      puts "-" * 40
      puts result
      puts "-" * 40
      puts "\nLines: #{result.lines.count}"
      puts "Characters: #{result.length}"
    else
      puts "\nInput cancelled"
    end
  end
  
  desc "compare", "Compare input methods"
  def compare
    puts "\n=== Input Method Comparison ===\n"
    
    # Method 1: Standard Reline
    puts "1. Standard Reline (current):"
    puts "   - Use \\ for line continuation"
    puts "   - Press Enter twice to submit"
    print "\nreline> "
    reline_input = $stdin.gets
    puts "   Result: #{reline_input.inspect}"
    
    # Method 2: Our advanced input
    puts "\n2. Advanced Input (new):"
    puts "   - Alt+Enter or Ctrl+J for new line"
    puts "   - Smart detection for multi-line"
    puts "   - Auto-indent and syntax highlighting"
    
    input = Thor::Interactive::UI::Components::AdvancedInput.new(
      prompt: "\nadv> ",
      show_line_numbers: false,
      syntax_highlighting: true
    )
    
    advanced_input = input.read_multiline
    puts "   Result: #{advanced_input.inspect}"
    
    puts "\n=== Comparison Complete ==="
  end
  
  desc "code", "Enter code with smart multi-line"
  def code
    puts "\n=== Code Entry Mode ==="
    puts "Enter will automatically continue for unclosed blocks:\n"
    
    input = Thor::Interactive::UI::Components::AdvancedInput.new(
      prompt: "code> ",
      continuation: "   .. ",
      show_line_numbers: true,
      syntax_highlighting: true,
      smart_newline: true,
      auto_indent: true
    )
    
    while true
      result = input.read_multiline
      
      break unless result
      
      puts "\nEvaluating:"
      puts result
      
      begin
        # Try to evaluate as Ruby code
        eval_result = eval(result)
        puts "=> #{eval_result.inspect}"
      rescue SyntaxError => e
        puts "Syntax Error: #{e.message}"
      rescue => e
        puts "Error: #{e.message}"
      end
      
      puts
    end
    
    puts "\nCode mode exited"
  end
  
  desc "json", "JSON entry with auto-formatting"
  def json
    require 'json'
    
    puts "\n=== JSON Entry Mode ==="
    puts "Brackets will auto-continue, Enter submits when balanced:\n"
    
    input = Thor::Interactive::UI::Components::AdvancedInput.new(
      prompt: "json> ",
      continuation: "      ",
      show_line_numbers: false,
      smart_newline: true,
      auto_indent: true
    )
    
    result = input.read_multiline
    
    if result
      begin
        parsed = JSON.parse(result)
        puts "\nParsed successfully!"
        puts JSON.pretty_generate(parsed)
      rescue JSON::ParserError => e
        puts "\nJSON Parse Error: #{e.message}"
        puts "\nRaw input:"
        puts result
      end
    else
      puts "\nCancelled"
    end
  end
  
  desc "poem", "Write a poem with easy line breaks"
  def poem
    puts "\n=== Poetry Mode ==="
    puts "Use Alt+Enter for line breaks, Enter when done:\n"
    
    input = Thor::Interactive::UI::Components::AdvancedInput.new(
      prompt: "poem> ",
      continuation: "      ",
      smart_newline: false,  # Disable smart detection for poetry
      auto_indent: false
    )
    
    result = input.read_multiline
    
    if result
      puts "\n" + "="*50
      puts result
      puts "="*50
      
      lines = result.lines
      words = result.split.size
      puts "\nPoem statistics:"
      puts "  Lines: #{lines.count}"
      puts "  Words: #{words}"
      puts "  Characters: #{result.length}"
    else
      puts "\nNo poem today?"
    end
  end
  
  desc "demo", "Interactive demo of all features"
  def demo
    loop do
      puts "\n=== Advanced Input Demo Menu ==="
      puts "1. Test multi-line input"
      puts "2. Compare input methods"
      puts "3. Code entry mode"
      puts "4. JSON entry mode"
      puts "5. Poetry mode"
      puts "6. Exit"
      
      print "\nChoice: "
      choice = $stdin.gets.chomp
      
      case choice
      when "1" then test
      when "2" then compare
      when "3" then code
      when "4" then json
      when "5" then poem
      when "6" then break
      else
        puts "Invalid choice"
      end
    end
    
    puts "\nGoodbye!"
  end
  
  default_task :demo
end

if __FILE__ == $0
  AdvancedInputDemo.start(ARGV)
end