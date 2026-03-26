# frozen_string_literal: true

class Thor
  module Interactive
    module TUI
      # Spinner animation for indicating activity during command execution.
      # Shows rotating fun messages like Claude Code.
      class Spinner
        FRAMES = %w[⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏].freeze
        INTERVAL = 0.08 # seconds between frames

        # Rotate through fun messages during long operations.
        # Apps can provide their own list via configure_interactive(spinner_messages: [...])
        DEFAULT_MESSAGES = [
          "Thinking",
          "Pondering",
          "Crunching",
          "Churning",
          "Whirring",
          "Brewing",
          "Conjuring",
          "Simmering",
          "Percolating",
          "Contemplating",
          "Noodling",
          "Ruminating",
          "Calculating",
          "Assembling",
          "Composing"
        ].freeze

        MESSAGE_ROTATE_INTERVAL = 3.0 # seconds between message changes

        attr_reader :message

        def initialize(messages: nil)
          @messages = messages || DEFAULT_MESSAGES
          @message = @messages.first
          @message_index = 0
          @last_message_change = Time.now
          @frame_index = 0
          @last_advance = Time.now
          @active = false
          @start_time = nil
        end

        def start(message = nil)
          @message = message || @messages.sample
          @message_index = @messages.index(@message) || 0
          @last_message_change = Time.now
          @active = true
          @start_time = Time.now
          @frame_index = 0
        end

        def stop
          @active = false
          @start_time = nil
        end

        def active?
          @active
        end

        def advance
          now = Time.now
          if now - @last_advance >= INTERVAL
            @frame_index = (@frame_index + 1) % FRAMES.length
            @last_advance = now
          end

          # Rotate message periodically
          if now - @last_message_change >= MESSAGE_ROTATE_INTERVAL
            @message_index = (@message_index + 1) % @messages.length
            @message = @messages[@message_index]
            @last_message_change = now
          end
        end

        def elapsed
          return 0 unless @start_time
          Time.now - @start_time
        end

        def to_s
          return "" unless @active

          advance
          elapsed_str = format_elapsed(elapsed)
          " #{FRAMES[@frame_index]} #{@message}... #{elapsed_str} "
        end

        private

        def format_elapsed(seconds)
          if seconds < 60
            "(#{seconds.round(1)}s)"
          else
            mins = (seconds / 60).to_i
            secs = (seconds % 60).to_i
            "(#{mins}m#{secs}s)"
          end
        end
      end
    end
  end
end
