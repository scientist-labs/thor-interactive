# frozen_string_literal: true

class Thor
  module Interactive
    module UI
      class FeatureDetection
        class << self
          def terminal_capabilities
            @capabilities ||= detect_capabilities
          end
          
          def supports?(feature)
            terminal_capabilities[feature] || false
          end
          
          def tty?
            $stdout.tty? && $stdin.tty?
          end
          
          def color_support?
            return false unless tty?
            return false if ENV['NO_COLOR']
            return true if ENV['FORCE_COLOR']
            
            case ENV['TERM']
            when nil, 'dumb'
              false
            when /color|xterm|screen|vt100|rxvt/i
              true
            else
              tty?
            end
          end
          
          def unicode_support?
            return false if ENV['LANG'].nil?
            ENV['LANG'].include?('UTF-8') || ENV['LANG'].include?('utf8')
          end
          
          def emoji_support?
            unicode_support? && !ENV['NO_EMOJI']
          end
          
          def animation_support?
            tty? && !ENV['CI'] && !ENV['NO_ANIMATION']
          end
          
          def terminal_width
            if tty? && $stdout.respond_to?(:winsize)
              $stdout.winsize[1]
            else
              ENV.fetch('COLUMNS', 80).to_i
            end
          rescue
            80
          end
          
          def terminal_height
            if tty? && $stdout.respond_to?(:winsize)
              $stdout.winsize[0]
            else
              ENV.fetch('LINES', 24).to_i
            end
          rescue
            24
          end
          
          def ui_library_available?(library)
            case library
            when :tty_prompt
              defined?(TTY::Prompt)
            when :tty_spinner
              defined?(TTY::Spinner)
            when :tty_progressbar
              defined?(TTY::ProgressBar)
            when :tty_cursor
              defined?(TTY::Cursor)
            when :pastel
              defined?(Pastel)
            else
              false
            end
          end
          
          private
          
          def detect_capabilities
            {
              tty: tty?,
              color: color_support?,
              unicode: unicode_support?,
              emoji: emoji_support?,
              animation: animation_support?,
              width: terminal_width,
              height: terminal_height
            }
          end
        end
      end
    end
  end
end