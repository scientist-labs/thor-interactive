#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "thor/interactive"

class MultiLineDemo < Thor
  include Thor::Interactive::Command
  
  # Configure with advanced UI and multi-line input
  configure_interactive(
    ui_mode: :advanced,
    input_mode: :multiline,
    input_height: 5,
    show_line_numbers: false,
    syntax_highlighting: :auto,
    mode_indicator: true,
    prompt: "ml> ",
    default_handler: proc do |input, thor_instance|
      if input.include?("\n")
        puts "=== Received Multi-line Input (#{input.lines.count} lines) ==="
        input.lines.each_with_index do |line, i|
          puts "  #{i + 1}: #{line}"
        end
      else
        puts "Natural language: #{input}"
      end
    end
  )
  
  desc "poem", "Enter a multi-line poem"
  def poem
    puts "Enter your poem (press Ctrl+Enter or double Enter to submit):"
    puts "Use \\ at end of line for continuation"
    puts
    
    # Simulate reading multi-line input
    input = multi_line_prompt("poem> ")
    
    if input && !input.strip.empty?
      puts "\n=== Your Poem ==="
      puts input
      puts "================="
      puts "\nLines: #{input.lines.count}"
      puts "Words: #{input.split.count}"
      puts "Characters: #{input.length}"
    else
      puts "No poem entered."
    end
  end
  
  desc "code", "Enter multi-line code"
  def code
    puts "Enter your code snippet:"
    
    input = multi_line_prompt("code> ")
    
    if input && !input.strip.empty?
      puts "\n=== Code Analysis ==="
      analyze_code(input)
    end
  end
  
  desc "script LANGUAGE", "Create a script in specified language"
  def script(language = "ruby")
    puts "Creating #{language} script. Enter code:"
    
    input = multi_line_prompt("#{language}> ")
    
    if input && !input.strip.empty?
      filename = "temp_script.#{extension_for(language)}"
      File.write(filename, input)
      puts "\nScript saved to: #{filename}"
      puts "Lines: #{input.lines.count}"
      
      # Syntax check for Ruby
      if language == "ruby"
        begin
          RubyVM::InstructionSequence.compile(input)
          puts "✓ Valid Ruby syntax"
        rescue SyntaxError => e
          puts "✗ Syntax error: #{e.message}"
        end
      end
    end
  end
  
  desc "json", "Enter and validate JSON"
  def json
    puts "Enter JSON data:"
    
    input = multi_line_prompt("json> ")
    
    if input && !input.strip.empty?
      begin
        require 'json'
        parsed = JSON.parse(input)
        puts "\n✓ Valid JSON"
        puts "Structure: #{parsed.class}"
        puts "Keys: #{parsed.keys.join(', ')}" if parsed.is_a?(Hash)
        puts "\nPretty printed:"
        puts JSON.pretty_generate(parsed)
      rescue JSON::ParserError => e
        puts "\n✗ Invalid JSON: #{e.message}"
      end
    end
  end
  
  desc "template", "Create a text template with placeholders"
  def template
    puts "Create a template with {{placeholders}}:"
    
    input = multi_line_prompt("template> ")
    
    if input && !input.strip.empty?
      placeholders = input.scan(/\{\{(\w+)\}\}/).flatten.uniq
      
      if placeholders.any?
        puts "\nFound placeholders: #{placeholders.join(', ')}"
        puts "\nFill in values:"
        
        values = {}
        placeholders.each do |ph|
          print "  #{ph}: "
          values[ph] = $stdin.gets.chomp
        end
        
        result = input.dup
        values.each do |key, value|
          result.gsub!("{{#{key}}}", value)
        end
        
        puts "\n=== Filled Template ==="
        puts result
      else
        puts "\nNo placeholders found. Template saved as-is."
      end
    end
  end
  
  desc "demo", "Interactive demonstration of multi-line features"
  def demo
    puts "=" * 50
    puts "Multi-line Input Demo"
    puts "=" * 50
    puts
    puts "This demo shows various multi-line input features:"
    puts
    puts "1. Basic multi-line with \\ continuation:"
    puts "   Type: hello world \\"
    puts "   Then: this continues on next line"
    puts
    puts "2. Natural line breaks (press Enter):"
    puts "   Type multiple lines naturally"
    puts "   Press double Enter to submit"
    puts
    puts "3. Commands work with multi-line too:"
    puts "   /poem - Enter a poem"
    puts "   /code - Enter code"
    puts "   /json - Enter JSON data"
    puts
    puts "Try it out in interactive mode!"
  end
  
  private
  
  def multi_line_prompt(prompt)
    # In a real implementation, this would use the enhanced input area
    puts "(Enter text, use \\ for continuation, empty line to finish)"
    
    lines = []
    continuation = false
    
    loop do
      line_prompt = continuation ? "... " : prompt
      print line_prompt
      line = $stdin.gets
      
      break if line.nil?
      line.chomp!
      
      if line.end_with?("\\")
        line.chomp!("\\")
        lines << line
        continuation = true
      elsif line.empty? && !continuation
        break
      else
        lines << line
        continuation = false
      end
    end
    
    lines.join("\n")
  end
  
  def analyze_code(code)
    lines = code.lines
    
    # Basic code analysis
    stats = {
      lines: lines.count,
      non_empty_lines: lines.reject(&:strip).count,
      indented_lines: lines.count { |l| l.start_with?("  ", "\t") },
      comment_lines: lines.count { |l| l.strip.start_with?("#", "//", "/*") },
      brackets: {
        parens: code.count("(") + code.count(")"),
        squares: code.count("[") + code.count("]"),
        curlies: code.count("{") + code.count("}")
      }
    }
    
    puts "Lines: #{stats[:lines]} (#{stats[:non_empty_lines]} non-empty)"
    puts "Indented lines: #{stats[:indented_lines]}"
    puts "Comment lines: #{stats[:comment_lines]}"
    puts "Brackets: () = #{stats[:brackets][:parens]}, [] = #{stats[:brackets][:squares]}, {} = #{stats[:brackets][:curlies]}"
    
    # Detect language
    language = detect_language(code)
    puts "Detected language: #{language}"
  end
  
  def detect_language(code)
    return "Ruby" if code.match?(/\b(def|end|puts|require|attr_|module|class)\b/)
    return "JavaScript" if code.match?(/\b(function|const|let|var|=&gt;|console\.log)\b/)
    return "Python" if code.match?(/\b(def|import|print|if __name__|from)\b.*:/)
    return "Java" if code.match?(/\b(public|private|class|void|System\.out)\b/)
    return "SQL" if code.match?(/\b(SELECT|FROM|WHERE|INSERT|UPDATE|DELETE)\b/i)
    return "JSON" if code.strip.start_with?("{", "[")
    return "HTML" if code.match?(/<[^>]+>/)
    "Unknown"
  end
  
  def extension_for(language)
    case language.downcase
    when "ruby" then "rb"
    when "python" then "py"
    when "javascript", "js" then "js"
    when "java" then "java"
    when "c" then "c"
    when "cpp", "c++" then "cpp"
    when "go" then "go"
    when "rust" then "rs"
    else "txt"
    end
  end
end

if __FILE__ == $0
  if ARGV.empty?
    puts "Starting Multi-line Input Demo..."
    puts "=" * 50
    puts "Available commands:"
    puts "  /poem     - Enter a multi-line poem"
    puts "  /code     - Enter code with syntax detection"
    puts "  /json     - Enter and validate JSON"
    puts "  /template - Create a template with placeholders"
    puts "  /script   - Create a script file"
    puts "  /demo     - See usage examples"
    puts
    puts "For multi-line input:"
    puts "  - End lines with \\ for continuation"
    puts "  - Press Enter twice to submit"
    puts "  - Use Ctrl+C to cancel"
    puts "=" * 50
    puts
    
    MultiLineDemo.start(["interactive"])
  else
    MultiLineDemo.start(ARGV)
  end
end