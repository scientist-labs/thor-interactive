# frozen_string_literal: true

class Thor
  module Interactive
    module TUI
      # Theming system for the TUI shell.
      # Predefined themes and custom color configuration.
      class Theme
        THEMES = {
          default: {
            output_fg: nil,
            output_border: :dark_gray,
            error_fg: :red,
            command_echo_fg: :dark_gray,
            system_fg: :cyan,
            input_fg: nil,
            input_border: :green,
            input_title_fg: :green,
            cursor_fg: :black,
            cursor_bg: :white,
            status_bar_fg: :white,
            status_bar_bg: :blue,
            completion_fg: :white,
            completion_bg: :dark_gray,
            completion_selected_fg: :black,
            completion_selected_bg: :cyan
          },
          dark: {
            output_fg: :gray,
            output_border: :dark_gray,
            error_fg: :light_red,
            command_echo_fg: :dark_gray,
            system_fg: :light_cyan,
            input_fg: :white,
            input_border: :light_green,
            input_title_fg: :light_green,
            cursor_fg: :black,
            cursor_bg: :light_yellow,
            status_bar_fg: :white,
            status_bar_bg: :dark_gray,
            completion_fg: :white,
            completion_bg: :dark_gray,
            completion_selected_fg: :black,
            completion_selected_bg: :light_cyan
          },
          light: {
            output_fg: :black,
            output_border: :gray,
            error_fg: :red,
            command_echo_fg: :gray,
            system_fg: :blue,
            input_fg: :black,
            input_border: :green,
            input_title_fg: :green,
            cursor_fg: :white,
            cursor_bg: :black,
            status_bar_fg: :white,
            status_bar_bg: :blue,
            completion_fg: :black,
            completion_bg: :gray,
            completion_selected_fg: :white,
            completion_selected_bg: :blue
          },
          minimal: {
            output_fg: nil,
            output_border: :dark_gray,
            error_fg: :red,
            command_echo_fg: :dark_gray,
            system_fg: :yellow,
            input_fg: nil,
            input_border: :dark_gray,
            input_title_fg: :white,
            cursor_fg: :black,
            cursor_bg: :white,
            status_bar_fg: :black,
            status_bar_bg: :white,
            completion_fg: :white,
            completion_bg: :dark_gray,
            completion_selected_fg: :black,
            completion_selected_bg: :white
          }
        }.freeze

        attr_reader :colors

        def initialize(theme = :default)
          @colors = if theme.is_a?(Hash)
            THEMES[:default].merge(theme)
          else
            THEMES.fetch(theme, THEMES[:default]).dup
          end
        end

        def [](key)
          @colors[key]
        end

        def style(key)
          color = @colors[key]
          color ? RatatuiRuby::Style::Style.new(fg: color) : nil
        end

        def output_style
          fg = @colors[:output_fg]
          fg ? RatatuiRuby::Style::Style.new(fg: fg) : nil
        end

        def error_style
          RatatuiRuby::Style::Style.new(fg: @colors[:error_fg])
        end

        def command_echo_style
          RatatuiRuby::Style::Style.new(fg: @colors[:command_echo_fg])
        end

        def system_style
          RatatuiRuby::Style::Style.new(fg: @colors[:system_fg])
        end

        def input_border_style
          RatatuiRuby::Style::Style.new(fg: @colors[:input_border])
        end

        def input_title_style
          RatatuiRuby::Style::Style.new(fg: @colors[:input_title_fg], modifiers: [:bold])
        end

        def cursor_style
          RatatuiRuby::Style::Style.new(fg: @colors[:cursor_fg], bg: @colors[:cursor_bg], modifiers: [:bold])
        end

        def output_border_style
          RatatuiRuby::Style::Style.new(fg: @colors[:output_border])
        end

        def status_bar_style
          RatatuiRuby::Style::Style.new(fg: @colors[:status_bar_fg], bg: @colors[:status_bar_bg])
        end

        def completion_style
          RatatuiRuby::Style::Style.new(fg: @colors[:completion_fg])
        end

        def completion_bg_style
          RatatuiRuby::Style::Style.new(bg: @colors[:completion_bg])
        end

        def completion_selected_style
          RatatuiRuby::Style::Style.new(
            fg: @colors[:completion_selected_fg],
            bg: @colors[:completion_selected_bg],
            modifiers: [:bold]
          )
        end
      end
    end
  end
end
