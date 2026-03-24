# frozen_string_literal: true

class Thor
  module Interactive
    module TUI
      # Stores captured command output with scrollback support.
      # Each entry is a hash with :text and optional :style keys.
      class OutputBuffer
        DEFAULT_MAX_LINES = 10_000

        attr_reader :scroll_offset

        def initialize(max_lines: DEFAULT_MAX_LINES)
          @lines = []
          @max_lines = max_lines
          @scroll_offset = 0
        end

        def append(text, style: nil)
          text.to_s.split("\n", -1).each do |line|
            @lines << {text: line, style: style}
          end
          trim_to_max
          # Auto-scroll to bottom when new content arrives
          @scroll_offset = 0
        end

        def lines
          @lines.dup
        end

        def line_count
          @lines.length
        end

        def empty?
          @lines.empty?
        end

        def clear
          @lines.clear
          @scroll_offset = 0
        end

        # Returns lines visible in a viewport of given height,
        # accounting for scroll_offset (0 = bottom, positive = scrolled up).
        def visible_lines(viewport_height)
          return @lines.last(viewport_height) if @scroll_offset == 0

          end_index = @lines.length - @scroll_offset
          end_index = @lines.length if end_index > @lines.length
          start_index = end_index - viewport_height
          start_index = 0 if start_index < 0

          @lines[start_index...end_index] || []
        end

        def scroll_up(amount = 1)
          max_offset = [@lines.length - 1, 0].max
          @scroll_offset = [@scroll_offset + amount, max_offset].min
        end

        def scroll_down(amount = 1)
          @scroll_offset = [@scroll_offset - amount, 0].max
        end

        def scroll_to_bottom
          @scroll_offset = 0
        end

        def scroll_to_top
          @scroll_offset = [@lines.length - 1, 0].max
        end

        def at_bottom?
          @scroll_offset == 0
        end

        private

        def trim_to_max
          @lines.shift(@lines.length - @max_lines) if @lines.length > @max_lines
        end
      end
    end
  end
end
