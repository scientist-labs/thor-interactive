# frozen_string_literal: true

class Thor
  module Interactive
    module TUI
      # Configurable status bar with left/center/right sections.
      # App authors provide lambdas that receive the Thor instance.
      class StatusBar
        attr_accessor :left, :center, :right

        def initialize(thor_class, thor_instance, options = {})
          @thor_class = thor_class
          @thor_instance = thor_instance

          config = options[:status_bar] || {}

          @left = config[:left] || ->(instance) { " #{instance.class.name}" }
          @center = config[:center] || ->(instance) { "" }
          @right = config[:right] || ->(instance) { " ready " }
        end

        def render_text(width, override_center: nil, override_right: nil)
          left_text = evaluate_section(@left)
          center_text = override_center || evaluate_section(@center)
          right_text = override_right || evaluate_section(@right)

          # Calculate spacing
          if center_text.empty?
            padding = width - left_text.length - right_text.length
            padding = 1 if padding < 1
            left_text + (" " * padding) + right_text
          else
            # Three-section layout
            left_space = width - left_text.length - center_text.length - right_text.length
            left_pad = [left_space / 2, 1].max
            right_pad = [left_space - left_pad, 1].max
            left_text + (" " * left_pad) + center_text + (" " * right_pad) + right_text
          end
        end

        private

        def evaluate_section(section)
          case section
          when Proc, Method
            section.arity == 0 ? section.call.to_s : section.call(@thor_instance).to_s
          when String
            section
          else
            section.to_s
          end
        rescue => e
          "(error)"
        end
      end
    end
  end
end
