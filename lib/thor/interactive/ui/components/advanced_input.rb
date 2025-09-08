# frozen_string_literal: true

require 'io/console'

class Thor
  module Interactive
    module UI
      module Components
        class AdvancedInput
          SPECIAL_KEYS = {
            "\e[A" => :up,
            "\e[B" => :down,
            "\e[C" => :right,
            "\e[D" => :left,
            "\e[H" => :home,
            "\e[F" => :end,
            "\177" => :backspace,
            "\e[3~" => :delete,
            "\e\r" => :alt_enter,    # Alt+Enter
            "\e\n" => :alt_enter,    # Alt+Enter (alternative)
            "\r" => :enter,
            "\n" => :enter,
            "\t" => :tab,
            "\e" => :escape,
            "\x03" => :ctrl_c,
            "\x04" => :ctrl_d,
            "\x0A" => :ctrl_j,       # Ctrl+J (alternative newline)
            "\x0B" => :ctrl_k,       # Ctrl+K (kill line)
            "\x0C" => :ctrl_l,       # Ctrl+L (clear)
            "\x15" => :ctrl_u,       # Ctrl+U (clear line)
            "\x17" => :ctrl_w,       # Ctrl+W (delete word)
          }
          
          attr_reader :lines, :cursor_row, :cursor_col
          
          def initialize(options = {})
            @options = options
            @lines = [""]
            @cursor_row = 0
            @cursor_col = 0
            @history = []
            @history_index = -1
            @prompt = options[:prompt] || "> "
            @continuation_prompt = options[:continuation] || "... "
            @multiline_keys = options[:multiline_keys] || [:alt_enter, :ctrl_j]
            @submit_keys = options[:submit_keys] || [:enter]
            @auto_indent = options[:auto_indent] != false
            @show_line_numbers = options[:show_line_numbers]
            @syntax_highlighting = options[:syntax_highlighting]
            @smart_newline = options[:smart_newline] != false
          end
          
          def read_multiline(initial_prompt = nil)
            @prompt = initial_prompt if initial_prompt
            @lines = [""]
            @cursor_row = 0
            @cursor_col = 0
            
            setup_terminal
            display_all
            
            loop do
              key = read_key
              result = handle_key(key)
              
              case result
              when :submit
                restore_terminal
                return @lines.join("\n")
              when :cancel
                restore_terminal
                return nil
              end
              
              display_all
            end
          ensure
            restore_terminal
          end
          
          private
          
          def setup_terminal
            @old_stty = `stty -g`.chomp if RUBY_PLATFORM =~ /darwin|linux/
            $stdin.raw!
            $stdout.sync = true
            hide_cursor
            clear_screen if @options[:clear_screen]
          end
          
          def restore_terminal
            show_cursor
            print "\n"
            $stdin.cooked!
            system("stty #{@old_stty}") if @old_stty
          rescue
            # Ignore errors during restoration
          end
          
          def read_key
            input = $stdin.getc
            
            # Check for escape sequences
            if input == "\e"
              begin
                input << $stdin.read_nonblock(5)
              rescue IO::WaitReadable
                # No more bytes available
              end
            end
            
            SPECIAL_KEYS[input] || input
          end
          
          def handle_key(key)
            case key
            when *@multiline_keys
              insert_newline
            when *@submit_keys
              return smart_submit
            when :escape
              return :cancel
            when :ctrl_c
              return :cancel
            when :ctrl_d
              return :submit if current_line.empty?
            when :up
              move_up
            when :down
              move_down
            when :left
              move_left
            when :right
              move_right
            when :home
              @cursor_col = 0
            when :end
              @cursor_col = current_line.length
            when :backspace
              delete_backward
            when :delete
              delete_forward
            when :ctrl_k
              kill_line
            when :ctrl_u
              clear_line
            when :ctrl_w
              delete_word
            when :tab
              handle_tab
            when String
              insert_char(key) if key.length == 1 && key.ord >= 32
            end
            
            nil
          end
          
          def smart_submit
            # If we're in a context that suggests multi-line, insert newline instead
            if @smart_newline && should_continue?
              insert_newline
              nil
            else
              :submit
            end
          end
          
          def should_continue?
            text = @lines.join("\n")
            
            # Check for unclosed brackets/braces
            return true if unbalanced?(text)
            
            # Check for line continuation indicators
            return true if current_line.end_with?("\\")
            
            # Check for keywords that typically start multi-line blocks
            return true if current_line =~ /^\s*(def|class|module|if|unless|case|while|for|begin|do)\b/
            
            # Check if we're in an indented line (suggests continuation)
            return true if current_line =~ /^\s+/ && @cursor_row > 0
            
            false
          end
          
          def unbalanced?(text)
            stack = []
            pairs = { '(' => ')', '[' => ']', '{' => '}', '"' => '"', "'" => "'" }
            
            text.each_char do |char|
              if pairs.key?(char)
                if char == '"' || char == "'"
                  if stack.last == char
                    stack.pop
                  else
                    stack.push(char)
                  end
                else
                  stack.push(char)
                end
              elsif pairs.value?(char)
                expected = pairs.key(char)
                return true if stack.empty? || stack.last != expected
                stack.pop unless char == '"' || char == "'"
              end
            end
            
            !stack.empty?
          end
          
          def insert_newline
            # Split current line at cursor
            before = current_line[0...@cursor_col]
            after = current_line[@cursor_col..-1] || ""
            
            @lines[@cursor_row] = before
            @cursor_row += 1
            
            # Auto-indent new line
            indent = @auto_indent ? calculate_indent(before) : ""
            @lines.insert(@cursor_row, indent + after)
            @cursor_col = indent.length
          end
          
          def calculate_indent(previous_line)
            # Get current indent
            current_indent = previous_line[/^\s*/]
            
            # Check if we should increase indent
            if previous_line =~ /[\{\[\(]\s*$/ || previous_line =~ /\b(def|class|module|if|unless|case|while|for|begin|do)\b/
              current_indent + "  "
            else
              current_indent
            end
          end
          
          def insert_char(char)
            current_line.insert(@cursor_col, char)
            @cursor_col += 1
          end
          
          def delete_backward
            return if @cursor_col == 0 && @cursor_row == 0
            
            if @cursor_col == 0
              # Merge with previous line
              prev_line = @lines[@cursor_row - 1]
              @cursor_col = prev_line.length
              @lines[@cursor_row - 1] = prev_line + current_line
              @lines.delete_at(@cursor_row)
              @cursor_row -= 1
            else
              current_line.slice!(@cursor_col - 1)
              @cursor_col -= 1
            end
          end
          
          def delete_forward
            if @cursor_col == current_line.length
              # Merge with next line if exists
              if @cursor_row < @lines.length - 1
                @lines[@cursor_row] = current_line + @lines[@cursor_row + 1]
                @lines.delete_at(@cursor_row + 1)
              end
            else
              current_line.slice!(@cursor_col)
            end
          end
          
          def move_up
            if @cursor_row > 0
              @cursor_row -= 1
              @cursor_col = [@cursor_col, current_line.length].min
            end
          end
          
          def move_down
            if @cursor_row < @lines.length - 1
              @cursor_row += 1
              @cursor_col = [@cursor_col, current_line.length].min
            end
          end
          
          def move_left
            if @cursor_col > 0
              @cursor_col -= 1
            elsif @cursor_row > 0
              @cursor_row -= 1
              @cursor_col = current_line.length
            end
          end
          
          def move_right
            if @cursor_col < current_line.length
              @cursor_col += 1
            elsif @cursor_row < @lines.length - 1
              @cursor_row += 1
              @cursor_col = 0
            end
          end
          
          def current_line
            @lines[@cursor_row]
          end
          
          def kill_line
            @lines[@cursor_row] = current_line[0...@cursor_col]
          end
          
          def clear_line
            @lines[@cursor_row] = ""
            @cursor_col = 0
          end
          
          def delete_word
            return if @cursor_col == 0
            
            # Find word boundary
            pos = @cursor_col - 1
            pos -= 1 while pos > 0 && current_line[pos] =~ /\s/
            pos -= 1 while pos > 0 && current_line[pos] =~ /\w/
            
            deleted = current_line[pos...@cursor_col]
            current_line[pos...@cursor_col] = ""
            @cursor_col = pos
          end
          
          def handle_tab
            # Simple tab insertion for now
            insert_char("  ")
          end
          
          def display_all
            # Clear and redraw
            clear_below_cursor
            move_to_start
            
            @lines.each_with_index do |line, i|
              prompt = i == 0 ? @prompt : @continuation_prompt
              
              if @show_line_numbers
                line_num = (i + 1).to_s.rjust(3)
                print "\e[90m#{line_num}│\e[0m "
              end
              
              print prompt
              
              if @syntax_highlighting
                print highlight_syntax(line)
              else
                print line
              end
              
              print "\n" unless i == @lines.length - 1
            end
            
            # Position cursor
            position_cursor
          end
          
          def highlight_syntax(line)
            # Simple syntax highlighting
            line
              .gsub(/\b(def|class|module|if|else|elsif|end|do|while|for|return)\b/, "\e[35m\\1\e[0m")  # Keywords in magenta
              .gsub(/"[^"]*"/, "\e[32m\\0\e[0m")  # Strings in green
              .gsub(/'[^']*'/, "\e[32m\\0\e[0m")  # Single quotes in green
              .gsub(/\d+/, "\e[36m\\0\e[0m")      # Numbers in cyan
              .gsub(/#.*$/, "\e[90m\\0\e[0m")     # Comments in gray
          end
          
          def position_cursor
            # Calculate visual position
            row = @cursor_row
            col = @cursor_col
            
            # Account for prompts
            if row == 0
              col += @prompt.length
            else
              col += @continuation_prompt.length
            end
            
            # Account for line numbers
            if @show_line_numbers
              col += 5  # "  1│ "
            end
            
            # Move cursor to position
            if row > 0
              print "\e[#{row}A"  # Move up
            end
            
            if col > 0
              print "\e[#{col + 1}G"  # Move to column
            end
          end
          
          def clear_screen
            print "\e[2J\e[H"
          end
          
          def clear_below_cursor
            print "\e[J"
          end
          
          def move_to_start
            print "\r"
          end
          
          def hide_cursor
            print "\e[?25l"
          end
          
          def show_cursor
            print "\e[?25h"
          end
        end
      end
    end
  end
end