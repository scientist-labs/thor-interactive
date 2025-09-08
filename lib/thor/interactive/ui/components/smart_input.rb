# frozen_string_literal: true

require "reline"

class Thor
  module Interactive
    module UI
      module Components
        # Smart multi-line input using Reline with better UX
        class SmartInput
          def initialize(options = {})
            @options = options
            @buffer = []
            @in_multiline = false
            @auto_multiline = options.fetch(:auto_multiline, true)
            @multiline_threshold = options.fetch(:multiline_threshold, 2)
            configure_reline
          end
          
          def read(prompt = "> ")
            if @auto_multiline && should_be_multiline?(prompt)
              read_multiline_smart(prompt)
            else
              read_with_continuation(prompt)
            end
          end
          
          private
          
          def configure_reline
            # Add custom key bindings if possible
            if defined?(Reline::KeyActor)
              # Try to add Alt+Enter binding
              Reline.add_dialog_proc(:multiline_hint) do |context|
                if @in_multiline
                  lines = context.buffer.count("\n") + 1
                  "  [#{lines} lines - Press Ctrl+D or Enter on empty line to submit]"
                end
              end
            end
          end
          
          def read_with_continuation(prompt)
            lines = []
            continuation = "  ... "
            current_prompt = prompt
            
            loop do
              line = Reline.readline(current_prompt, true)
              
              # Handle EOF (Ctrl+D)
              return lines.join("\n") if line.nil? && !lines.empty?
              return nil if line.nil?
              
              # Handle empty line in multiline mode
              if line.strip.empty? && !lines.empty?
                return lines.join("\n")
              end
              
              # Check for explicit continuation
              if line.end_with?("\\")
                lines << line.chomp("\\")
                current_prompt = continuation
                next
              end
              
              # Check for implicit continuation
              if should_continue?(line, lines)
                lines << line
                current_prompt = continuation
                next
              end
              
              # Single line or final line
              lines << line unless line.strip.empty?
              return lines.empty? ? nil : lines.join("\n")
            end
          end
          
          def read_multiline_smart(prompt)
            puts "[Multi-line mode - Press Enter twice or Ctrl+D to submit]"
            
            lines = []
            continuation = "  ... "
            current_prompt = prompt
            empty_count = 0
            
            loop do
              line = Reline.readline(current_prompt, true)
              
              # Handle EOF (Ctrl+D)
              return lines.join("\n") if line.nil?
              
              # Track consecutive empty lines
              if line.strip.empty?
                empty_count += 1
                return lines.join("\n") if empty_count >= 2
                lines << line
              else
                empty_count = 0
                lines << line
              end
              
              current_prompt = continuation
            end
          end
          
          def should_be_multiline?(input)
            # Heuristics for when to automatically use multi-line mode
            return true if input =~ /\b(def|class|module|begin)\b/
            return true if input =~ /\bdoc\b/i
            return true if input =~ /\bpoem\b/i
            return true if input =~ /\bcode\b/i
            return true if input =~ /\bmulti/i
            false
          end
          
          def should_continue?(current_line, previous_lines)
            all_text = (previous_lines + [current_line]).join("\n")
            
            # Check for unclosed delimiters
            return true if unclosed_delimiters?(all_text)
            
            # Check for keywords that start blocks
            return true if current_line =~ /^\s*(def|class|module|if|unless|case|while|until|for|begin|do)\b/
            
            # Check for indentation suggesting continuation
            if previous_lines.any? && current_line =~ /^\s+/
              prev_indent = previous_lines.last[/^\s*/].length
              curr_indent = current_line[/^\s*/].length
              return true if curr_indent > prev_indent
            end
            
            false
          end
          
          def unclosed_delimiters?(text)
            # Track delimiter balance
            delimiters = {
              '(' => ')',
              '[' => ']',
              '{' => '}'
            }
            
            quotes = ['"', "'"]
            in_string = nil
            escape_next = false
            stack = []
            
            text.each_char.with_index do |char, i|
              if escape_next
                escape_next = false
                next
              end
              
              if char == '\\'
                escape_next = true
                next
              end
              
              # Handle strings
              if quotes.include?(char)
                if in_string == char
                  in_string = nil
                elsif in_string.nil?
                  in_string = char
                end
                next
              end
              
              next if in_string
              
              # Handle delimiters
              if delimiters.key?(char)
                stack.push(char)
              elsif delimiters.value?(char)
                expected = delimiters.key(char)
                return false if stack.empty? || stack.last != expected
                stack.pop
              end
            end
            
            # Check for unclosed strings or delimiters
            !stack.empty? || !in_string.nil?
          end
        end
        
        # Alternative: Simple multi-line with visual cues
        class SimpleMultilineInput
          def self.read(prompt = "> ", options = {})
            lines = []
            continuation = options[:continuation] || "  ... "
            
            puts options[:hint] if options[:hint]
            
            loop do
              current_prompt = lines.empty? ? prompt : continuation
              line = Reline.readline(current_prompt, true)
              
              # Ctrl+D to submit
              return format_result(lines, options) if line.nil?
              
              # Empty line to submit (when we have content)
              if line.strip.empty?
                if lines.any?
                  return format_result(lines, options)
                else
                  next
                end
              end
              
              # Add line and show count
              lines << line
              if options[:show_count] && lines.length > 1
                print "\e[90m[#{lines.length} lines]\e[0m\r"
              end
            end
          end
          
          def self.format_result(lines, options)
            return nil if lines.empty?
            
            result = lines.join("\n")
            
            # Optional formatting
            if options[:strip_empty]
              result = lines.reject(&:empty?).join("\n")
            end
            
            if options[:indent]
              result = lines.map { |l| "  #{l}" }.join("\n")
            end
            
            result
          end
        end
      end
    end
  end
end