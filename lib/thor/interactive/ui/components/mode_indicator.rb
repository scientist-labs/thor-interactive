# frozen_string_literal: true

class Thor
  module Interactive
    module UI
      module Components
        class ModeIndicator
          MODES = {
            insert: { text: "INSERT", color: :green, symbol: "✎" },
            normal: { text: "NORMAL", color: :blue, symbol: "◆" },
            command: { text: "COMMAND", color: :yellow, symbol: ">" },
            visual: { text: "VISUAL", color: :magenta, symbol: "▣" },
            processing: { text: "PROCESSING", color: :cyan, symbol: "⟳" },
            error: { text: "ERROR", color: :red, symbol: "✗" }
          }.freeze
          
          attr_reader :current_mode, :position
          
          def initialize(config = {})
            @current_mode = :normal
            @position = config[:position] || :bottom_right
            @style = config[:style] || :full  # :full, :compact, :minimal
            @use_colors = FeatureDetection.color_support?
            @use_unicode = FeatureDetection.unicode_support?
            @pastel = Pastel.new if defined?(Pastel) && @use_colors
          end
          
          def set_mode(mode)
            return unless MODES.key?(mode)
            @current_mode = mode
            update_display
          end
          
          def display
            return "" unless MODES.key?(@current_mode)
            
            mode_info = MODES[@current_mode]
            
            case @style
            when :full
              full_display(mode_info)
            when :compact
              compact_display(mode_info)
            when :minimal
              minimal_display(mode_info)
            else
              mode_info[:text]
            end
          end
          
          def update_display
            clear_current
            print positioned_text(display)
          rescue
            # Silently fail if display update fails
          end
          
          private
          
          def full_display(mode_info)
            text = " #{mode_info[:symbol]} #{mode_info[:text]} " if @use_unicode
            text ||= " [#{mode_info[:text]}] "
            
            if @pastel
              @pastel.send(mode_info[:color], text)
            else
              text
            end
          end
          
          def compact_display(mode_info)
            text = @use_unicode ? mode_info[:symbol] : mode_info[:text][0]
            
            if @pastel
              @pastel.send(mode_info[:color], text)
            else
              "[#{text}]"
            end
          end
          
          def minimal_display(mode_info)
            mode_info[:text][0..2].upcase
          end
          
          def positioned_text(text)
            return text unless FeatureDetection.tty?
            
            case @position
            when :bottom_right
              position_bottom_right(text)
            when :bottom_left
              position_bottom_left(text)
            when :top_right
              position_top_right(text)
            when :inline
              text
            else
              text
            end
          end
          
          def position_bottom_right(text)
            width = FeatureDetection.terminal_width
            height = FeatureDetection.terminal_height
            text_width = text.gsub(/\e\[[0-9;]*m/, '').length  # Remove ANSI codes for length
            
            # Position cursor at bottom right
            "\e[#{height};#{width - text_width}H#{text}\e[#{height};1H"
          rescue
            text
          end
          
          def position_bottom_left(text)
            height = FeatureDetection.terminal_height
            "\e[#{height};1H#{text}"
          rescue
            text
          end
          
          def position_top_right(text)
            width = FeatureDetection.terminal_width
            text_width = text.gsub(/\e\[[0-9;]*m/, '').length
            
            "\e[1;#{width - text_width}H#{text}"
          rescue
            text
          end
          
          def clear_current
            # Clear the area where mode indicator was displayed
            return unless FeatureDetection.tty?
            
            # Save cursor, clear area, restore cursor
            print "\e[s"  # Save cursor position
            
            case @position
            when :bottom_right, :bottom_left
              height = FeatureDetection.terminal_height
              print "\e[#{height};1H\e[K"  # Clear bottom line
            when :top_right
              print "\e[1;1H\e[K"  # Clear top line
            end
            
            print "\e[u"  # Restore cursor position
          rescue
            # Silently fail
          end
        end
      end
    end
  end
end