# frozen_string_literal: true

require 'tty-reader' rescue nil

class Thor
  module Interactive
    module UI
      module Components
        class InputArea
          attr_reader :mode, :height, :buffer, :cursor_position
          
          def initialize(config = {})
            @height = config[:height] || 5
            @submit_key = config[:submit_key] || :ctrl_enter
            @cancel_key = config[:cancel_key] || :escape
            @show_line_numbers = config[:show_line_numbers] || false
            @syntax_highlighting = config[:syntax_highlighting] || :auto
            @mode = :single_line  # :single_line or :multi_line
            @buffer = []
            @cursor_position = { line: 0, col: 0 }
            @reader = create_reader if defined?(TTY::Reader)
          end
          
          def read_multiline(prompt = "> ")
            return read_fallback(prompt) unless @reader
            
            @mode = :multi_line
            @buffer = [""]
            @cursor_position = { line: 0, col: 0 }
            
            clear_input_area
            display_prompt(prompt)
            
            loop do
              key = @reader.read_keypress
              
              case key
              when @submit_key, "\r\n"  # Submit on configured key
                break if should_submit?
                add_newline
              when @cancel_key, "\e"     # Cancel on ESC
                @buffer = [""]
                break
              when "\r", "\n"            # Regular enter adds newline
                add_newline
              when "\b", "\x7F"          # Backspace
                handle_backspace
              when "\t"                  # Tab
                handle_tab
              else
                insert_char(key) if key.is_a?(String) && key.length == 1
              end
              
              refresh_display(prompt)
            end
            
            @buffer.join("\n")
          end
          
          def read_single_line(prompt = "> ")
            return read_fallback(prompt) unless @reader
            
            @mode = :single_line
            input = ""
            
            print prompt
            
            @reader.on(:keypress) do |event|
              case event.value
              when "\r", "\n"
                break
              when "\e"
                input = ""
                break
              else
                input << event.value if event.value.is_a?(String)
                print event.value
              end
            end
            
            @reader.read_line
          rescue
            read_fallback(prompt)
          end
          
          def detect_syntax(input)
            return :command if input.start_with?('/')
            return :help if input.match?(/^\s*(help|h|\?)\s*$/i)
            return :exit if input.match?(/^\s*(exit|quit|q)\s*$/i)
            :natural_language
          end
          
          def highlight_syntax(text, type = nil)
            return text unless FeatureDetection.color_support?
            
            type ||= detect_syntax(text)
            
            case type
            when :command
              colorize(text, :blue)
            when :help
              colorize(text, :yellow)
            when :exit
              colorize(text, :red)
            else
              text
            end
          end
          
          private
          
          def create_reader
            return nil unless defined?(TTY::Reader)
            
            TTY::Reader.new(
              interrupt: :error,
              track_history: false,
              history_cycle: false
            )
          rescue
            nil
          end
          
          def read_fallback(prompt)
            print prompt
            $stdin.gets&.chomp || ""
          end
          
          def should_submit?
            # In multi-line mode, check for submit key combo
            # For now, submit on empty line (double enter)
            @buffer.last.empty? && @buffer.size > 1
          end
          
          def add_newline
            @buffer << ""
            @cursor_position[:line] += 1
            @cursor_position[:col] = 0
          end
          
          def handle_backspace
            if @cursor_position[:col] > 0
              @buffer[@cursor_position[:line]].slice!(@cursor_position[:col] - 1)
              @cursor_position[:col] -= 1
            elsif @cursor_position[:line] > 0
              # Join with previous line
              prev_line = @buffer[@cursor_position[:line] - 1]
              current_line = @buffer.delete_at(@cursor_position[:line])
              @buffer[@cursor_position[:line] - 1] = prev_line + current_line
              @cursor_position[:line] -= 1
              @cursor_position[:col] = prev_line.length
            end
          end
          
          def handle_tab
            # Insert 2 spaces for tab
            insert_char("  ")
          end
          
          def insert_char(char)
            line = @buffer[@cursor_position[:line]]
            line.insert(@cursor_position[:col], char)
            @cursor_position[:col] += char.length
          end
          
          def clear_input_area
            # Clear the input area using ANSI codes
            print "\e[#{@height}A" if @height > 1  # Move up
            print "\e[2K"                           # Clear line
            @height.times { print "\e[B\e[2K" }     # Clear below
            print "\e[#{@height}A"                  # Move back up
          rescue
            # Fallback if ANSI codes don't work
          end
          
          def display_prompt(prompt)
            print prompt
          end
          
          def refresh_display(prompt)
            # Move to start of input area
            print "\r\e[K"
            
            # Display current buffer with syntax highlighting
            if @show_line_numbers && @buffer.size > 1
              @buffer.each_with_index do |line, i|
                print "#{i + 1}: " if i > 0
                print highlight_syntax(line)
                print "\n" if i < @buffer.size - 1
              end
            else
              print highlight_syntax(@buffer.join("\n"))
            end
          rescue
            # Fallback display
            print @buffer.join("\n")
          end
          
          def colorize(text, color)
            return text unless defined?(Pastel)
            @pastel ||= Pastel.new
            @pastel.send(color, text)
          rescue
            text
          end
        end
      end
    end
  end
end