# frozen_string_literal: true

class Thor
  module Interactive
    module TUI
      # Multi-line text buffer with cursor tracking.
      # Used as the data model for the input area in the TUI shell.
      class TextInput
        attr_reader :cursor_row, :cursor_col

        def initialize
          @lines = [+""]
          @cursor_row = 0
          @cursor_col = 0
          @history = []
          @history_index = nil
          @saved_input = nil
        end

        def content
          @lines.join("\n")
        end

        def empty?
          @lines.length == 1 && @lines[0].empty?
        end

        def lines
          @lines.dup
        end

        def line_count
          @lines.length
        end

        def current_line
          @lines[@cursor_row] || ""
        end

        def insert_char(ch)
          @lines[@cursor_row].insert(@cursor_col, ch)
          @cursor_col += ch.length
        end

        def insert_text(text)
          text_lines = text.split("\n", -1)
          if text_lines.length == 1
            insert_char(text_lines[0])
          else
            # Split current line at cursor
            before = @lines[@cursor_row][0...@cursor_col]
            after = @lines[@cursor_row][@cursor_col..]

            # First fragment joins with text before cursor
            @lines[@cursor_row] = before + text_lines[0]

            # Middle lines insert after current row
            text_lines[1...-1].each_with_index do |line, i|
              @lines.insert(@cursor_row + 1 + i, line)
            end

            # Last fragment joins with text after cursor
            last_line = text_lines.last + after.to_s
            @lines.insert(@cursor_row + text_lines.length - 1, last_line)

            @cursor_row += text_lines.length - 1
            @cursor_col = text_lines.last.length
          end
        end

        def newline
          # Split current line at cursor
          before = @lines[@cursor_row][0...@cursor_col]
          after = @lines[@cursor_row][@cursor_col..]

          @lines[@cursor_row] = before
          @lines.insert(@cursor_row + 1, after.to_s)
          @cursor_row += 1
          @cursor_col = 0
        end

        def backspace
          if @cursor_col > 0
            @lines[@cursor_row] = @lines[@cursor_row][0...@cursor_col - 1] + @lines[@cursor_row][@cursor_col..]
            @cursor_col -= 1
          elsif @cursor_row > 0
            # Join with previous line
            prev_col = @lines[@cursor_row - 1].length
            @lines[@cursor_row - 1] += @lines[@cursor_row]
            @lines.delete_at(@cursor_row)
            @cursor_row -= 1
            @cursor_col = prev_col
          end
        end

        def delete_char
          if @cursor_col < @lines[@cursor_row].length
            @lines[@cursor_row] = @lines[@cursor_row][0...@cursor_col] + @lines[@cursor_row][@cursor_col + 1..]
          elsif @cursor_row < @lines.length - 1
            # Join with next line
            @lines[@cursor_row] += @lines[@cursor_row + 1]
            @lines.delete_at(@cursor_row + 1)
          end
        end

        def move_left
          if @cursor_col > 0
            @cursor_col -= 1
          elsif @cursor_row > 0
            @cursor_row -= 1
            @cursor_col = @lines[@cursor_row].length
          end
        end

        def move_right
          if @cursor_col < @lines[@cursor_row].length
            @cursor_col += 1
          elsif @cursor_row < @lines.length - 1
            @cursor_row += 1
            @cursor_col = 0
          end
        end

        def move_up
          if @cursor_row > 0
            @cursor_row -= 1
            @cursor_col = [@cursor_col, @lines[@cursor_row].length].min
          end
        end

        def move_down
          if @cursor_row < @lines.length - 1
            @cursor_row += 1
            @cursor_col = [@cursor_col, @lines[@cursor_row].length].min
          end
        end

        def move_home
          @cursor_col = 0
        end

        def move_end
          @cursor_col = @lines[@cursor_row].length
        end

        def clear
          @lines = [+""]
          @cursor_row = 0
          @cursor_col = 0
        end

        # Submit the current content and add to history.
        # Returns the content and clears the input.
        def submit
          text = content
          add_to_history(text) unless text.strip.empty?
          clear
          @history_index = nil
          @saved_input = nil
          text
        end

        def add_to_history(text)
          # Don't add duplicates of the most recent entry
          @history.push(text) unless @history.last == text
        end

        def history_back
          return false if @history.empty?

          if @history_index.nil?
            @saved_input = content
            @history_index = @history.length - 1
          elsif @history_index > 0
            @history_index -= 1
          else
            return false
          end

          load_from_string(@history[@history_index])
          true
        end

        def history_forward
          return false if @history_index.nil?

          if @history_index < @history.length - 1
            @history_index += 1
            load_from_string(@history[@history_index])
          else
            @history_index = nil
            load_from_string(@saved_input || "")
            @saved_input = nil
          end
          true
        end

        # Load history entries from an array of strings
        def load_history(entries)
          @history = entries.dup
        end

        def history_entries
          @history.dup
        end

        private

        def load_from_string(str)
          @lines = str.split("\n", -1).map { |s| +s }
          @lines = [+""] if @lines.empty?
          @cursor_row = @lines.length - 1
          @cursor_col = @lines[@cursor_row].length
        end
      end
    end
  end
end
