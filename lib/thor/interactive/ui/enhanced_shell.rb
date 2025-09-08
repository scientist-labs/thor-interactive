# frozen_string_literal: true

require_relative "components/input_area"
require_relative "components/mode_indicator"

class Thor
  module Interactive
    module UI
      class EnhancedShell < Shell
        attr_reader :input_area, :mode_indicator, :multi_line_history
        
        def initialize(thor_class, options = {})
          super(thor_class, options)
          @multi_line_history = []
          
          if UI.enabled? && @merged_options[:input_mode] == :multiline
            setup_enhanced_input
          end
        end
        
        def start
          if @input_area
            start_enhanced
          else
            super
          end
        end
        
        private
        
        def setup_enhanced_input
          @input_area = Components::InputArea.new(
            height: @merged_options[:input_height] || 5,
            show_line_numbers: @merged_options[:show_line_numbers] || false,
            syntax_highlighting: @merged_options[:syntax_highlighting] || :auto
          )
          
          @mode_indicator = Components::ModeIndicator.new(
            position: @merged_options[:mode_position] || :bottom_right,
            style: @merged_options[:mode_style] || :full
          )
          
          @multi_line_history = []
        end
        
        def start_enhanced
          setup_environment
          load_history
          show_welcome
          
          @mode_indicator&.set_mode(:normal)
          
          loop do
            begin
              @mode_indicator&.set_mode(:insert)
              
              # Read input (single or multi-line based on context)
              input = read_enhanced_input
              
              break if should_exit?(input)
              
              @mode_indicator&.set_mode(:processing)
              process_input(input)
              
              @mode_indicator&.set_mode(:normal)
              
              # Save to history
              save_to_enhanced_history(input) unless input.strip.empty?
              
            rescue Interrupt
              puts "\n^C"
              @mode_indicator&.set_mode(:normal)
              next
            rescue StandardError => e
              @mode_indicator&.set_mode(:error)
              puts "Error: #{e.message}"
              puts e.backtrace if ENV["DEBUG"]
              @mode_indicator&.set_mode(:normal)
            end
          end
          
        ensure
          cleanup
        end
        
        def read_enhanced_input
          # Determine if we should use multi-line based on context
          prompt = format_prompt
          
          # Check if last input suggests multi-line continuation
          if should_use_multiline?
            @input_area.read_multiline(prompt)
          else
            # Try to read single line first
            input = Reline.readline(prompt, true)
            
            # If input ends with continuation marker, switch to multi-line
            if input&.end_with?("\\")
              input.chomp!("\\")
              input + "\n" + @input_area.read_multiline("... ")
            else
              input
            end
          end
        end
        
        def should_use_multiline?
          # Heuristics for when to use multi-line input
          return true if @force_multiline
          return true if @last_input&.end_with?("\\")
          false
        end
        
        def save_to_enhanced_history(input)
          # Save both to regular history and multi-line history
          if input.include?("\n")
            @multi_line_history << {
              input: input,
              timestamp: Time.now,
              lines: input.lines.count
            }
            
            # Save compressed version to regular history
            Reline::HISTORY << input.gsub("\n", " ↩ ")
          else
            Reline::HISTORY << input
          end
          
          save_history
        end
        
        def show_multiline_history
          return puts "No multi-line history" if @multi_line_history.empty?
          
          puts "\nMulti-line History:"
          puts "-" * 40
          
          @multi_line_history.last(10).each_with_index do |entry, i|
            puts "\n[#{i + 1}] #{entry[:timestamp].strftime('%H:%M:%S')} (#{entry[:lines]} lines)"
            puts entry[:input].lines.map { |l| "  #{l}" }.join
          end
        end
        
        def enhanced_help
          super
          
          if @input_area
            puts "\nEnhanced Input Controls:"
            puts "  Ctrl+Enter       Submit multi-line input"
            puts "  ESC              Cancel current input"
            puts "  \\               Line continuation"
            puts "  /multiline       Toggle multi-line mode"
            puts "  /history         Show multi-line history"
            puts
          end
        end
        
        def handle_slash_command(command_line)
          # Handle enhanced commands
          case command_line
          when "multiline"
            @force_multiline = !@force_multiline
            mode = @force_multiline ? "enabled" : "disabled"
            puts "Multi-line mode #{mode}"
            return
          when "history"
            show_multiline_history
            return
          when "mode"
            modes = [:normal, :insert, :command, :visual]
            current_idx = modes.index(@mode_indicator.current_mode)
            next_mode = modes[(current_idx + 1) % modes.length]
            @mode_indicator.set_mode(next_mode)
            puts "Mode changed to: #{next_mode}"
            return
          end
          
          super(command_line)
        end
      end
    end
  end
end