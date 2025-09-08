# frozen_string_literal: true

require "io/console"

class Thor
  module Interactive
    module UI
      module Components
        class StatusBar
          attr_reader :position, :style, :items, :width
          attr_accessor :visible
          
          def initialize(position: :bottom, style: :single_line, width: nil)
            @position = position
            @style = style
            @width = width || terminal_width
            @items = {}
            @visible = true
            @mutex = Mutex.new
            @last_render = ""
          end
          
          def set(key, value, options = {})
            @mutex.synchronize do
              @items[key] = {
                value: value,
                position: options[:position] || :left,
                color: options[:color],
                format: options[:format],
                priority: options[:priority] || 0
              }
            end
            refresh
          end
          
          def remove(key)
            @mutex.synchronize do
              @items.delete(key)
            end
            refresh
          end
          
          def clear
            @mutex.synchronize do
              @items.clear
            end
            refresh
          end
          
          def hide
            @visible = false
            clear_line
          end
          
          def show
            @visible = true
            refresh
          end
          
          def refresh
            return unless @visible && tty?
            
            content = render_content
            return if content == @last_render
            
            @last_render = content
            display_status(content)
          end
          
          def with_hidden
            was_visible = @visible
            hide if was_visible
            yield
          ensure
            show if was_visible
          end
          
          private
          
          def render_content
            @mutex.synchronize do
              return "" if @items.empty?
              
              left_items = []
              center_items = []
              right_items = []
              
              sorted_items = @items.sort_by { |_, v| -v[:priority] }
              
              sorted_items.each do |key, item|
                formatted = format_item(key, item)
                
                case item[:position]
                when :left
                  left_items << formatted
                when :center
                  center_items << formatted
                when :right
                  right_items << formatted
                end
              end
              
              build_status_line(left_items, center_items, right_items)
            end
          end
          
          def format_item(key, item)
            text = item[:value].to_s
            
            if item[:format]
              text = item[:format].call(text) rescue text
            end
            
            if item[:color] && color_support?
              text = colorize(text, item[:color])
            end
            
            text
          end
          
          def build_status_line(left, center, right)
            case @style
            when :single_line
              build_single_line(left, center, right)
            when :multi_line
              build_multi_line(left, center, right)
            when :compact
              build_compact_line(left, center, right)
            else
              build_single_line(left, center, right)
            end
          end
          
          def build_single_line(left, center, right)
            left_text = left.join(" | ")
            center_text = center.join(" | ")
            right_text = right.join(" | ")
            
            available_width = @width - 4
            
            if center_text.empty? && right_text.empty?
              truncate(left_text, available_width)
            elsif center_text.empty?
              left_width = (available_width * 0.7).to_i
              right_width = available_width - left_width - 3
              
              left_part = truncate(left_text, left_width)
              right_part = truncate(right_text, right_width)
              
              "#{left_part.ljust(left_width)}   #{right_part.rjust(right_width)}"
            else
              section_width = available_width / 3
              
              left_part = truncate(left_text, section_width)
              center_part = truncate(center_text, section_width)
              right_part = truncate(right_text, section_width)
              
              left_part.ljust(section_width) + 
                center_part.center(section_width) + 
                right_part.rjust(section_width)
            end
          end
          
          def build_multi_line(left, center, right)
            lines = []
            lines << left.join(" | ") unless left.empty?
            lines << center.map { |c| " " * (@width / 2 - c.length / 2) + c }.join("\n") unless center.empty?
            lines << right.map { |r| " " * (@width - r.length) + r }.join("\n") unless right.empty?
            lines.join("\n")
          end
          
          def build_compact_line(left, center, right)
            items = left + center + right
            truncate(items.join(" "), @width - 2)
          end
          
          def display_status(content)
            return if content.empty?
            
            case @position
            when :bottom
              display_at_bottom(content)
            when :top
              display_at_top(content)
            when :inline
              display_inline(content)
            end
          end
          
          def display_at_bottom(content)
            save_cursor
            move_to_bottom
            clear_line
            print "\r#{content}"
            restore_cursor
          end
          
          def display_at_top(content)
            save_cursor
            move_to_top
            clear_line
            print "\r#{content}"
            restore_cursor
          end
          
          def display_inline(content)
            print "\r#{content}"
          end
          
          def truncate(text, max_width)
            return text if text.length <= max_width
            return "..." if max_width <= 3
            
            text[0...(max_width - 3)] + "..."
          end
          
          def save_cursor
            print "\e[s" if tty?
          end
          
          def restore_cursor
            print "\e[u" if tty?
          end
          
          def move_to_bottom
            rows = terminal_height
            print "\e[#{rows};1H" if tty?
          end
          
          def move_to_top
            print "\e[1;1H" if tty?
          end
          
          def clear_line
            print "\e[2K" if tty?
          end
          
          def colorize(text, color)
            colors = {
              black: 30, red: 31, green: 32, yellow: 33,
              blue: 34, magenta: 35, cyan: 36, white: 37,
              gray: 90, bright_red: 91, bright_green: 92,
              bright_yellow: 93, bright_blue: 94, bright_magenta: 95,
              bright_cyan: 96, bright_white: 97
            }
            
            code = colors[color] || 37
            "\e[#{code}m#{text}\e[0m"
          end
          
          def terminal_width
            if tty? && $stdout.respond_to?(:winsize)
              $stdout.winsize[1]
            else
              80
            end
          rescue
            80
          end
          
          def terminal_height
            if tty? && $stdout.respond_to?(:winsize)
              $stdout.winsize[0]
            else
              24
            end
          rescue
            24
          end
          
          def tty?
            $stdout.tty? && !ENV['CI']
          end
          
          def color_support?
            return false unless tty?
            return true if ENV['COLORTERM'] == 'truecolor'
            return true if ENV['TERM']&.include?('256')
            return true if ENV['TERM']&.include?('color')
            false
          end
        end
      end
    end
  end
end