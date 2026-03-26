# frozen_string_literal: true

require "reline"
require_relative "command_dispatch"

class Thor
  module Interactive
    class Shell
      DEFAULT_PROMPT = "> "
      DEFAULT_HISTORY_FILE = "~/.thor_interactive_history"

      attr_reader :thor_class, :thor_instance, :prompt

      include CommandDispatch

      def initialize(thor_class, options = {})
        @thor_class = thor_class
        @thor_instance = thor_class.new

        # Merge class-level interactive options if available
        merged_options = {}
        if thor_class.respond_to?(:interactive_options)
          merged_options.merge!(thor_class.interactive_options)
        end
        merged_options.merge!(options)

        @merged_options = merged_options
        @default_handler = merged_options[:default_handler]
        @prompt = merged_options[:prompt] || DEFAULT_PROMPT
        @history_file = File.expand_path(merged_options[:history_file] || DEFAULT_HISTORY_FILE)

        # Ctrl-C handling configuration
        @ctrl_c_behavior = merged_options[:ctrl_c_behavior] || :clear_prompt
        @double_ctrl_c_timeout = merged_options.key?(:double_ctrl_c_timeout) ?
                                merged_options[:double_ctrl_c_timeout] : 0.5
        @last_interrupt_time = nil

        setup_completion
        load_history
      end

      def start
        # Track that we're in an interactive session
        was_in_session = ENV["THOR_INTERACTIVE_SESSION"]
        nesting_level = ENV["THOR_INTERACTIVE_LEVEL"].to_i

        ENV["THOR_INTERACTIVE_SESSION"] = "true"
        ENV["THOR_INTERACTIVE_LEVEL"] = (nesting_level + 1).to_s

        puts "(Debug: Interactive session started, level #{nesting_level + 1})" if ENV["DEBUG"]

        # Adjust prompt for nested sessions if configured
        display_prompt = @prompt
        if nesting_level > 0 && @merged_options[:nested_prompt_format]
          display_prompt = @merged_options[:nested_prompt_format] % [nesting_level + 1, @prompt]
        elsif nesting_level > 0
          display_prompt = "(#{nesting_level + 1}) #{@prompt}"
        end

        show_welcome(nesting_level)

        puts "(Debug: Entering main loop)" if ENV["DEBUG"]

        loop do
          begin
            line = Reline.readline(display_prompt, true)
            puts "(Debug: Got input: #{line.inspect})" if ENV["DEBUG"]

            # Reset interrupt tracking on successful input
            @last_interrupt_time = nil if line

            if should_exit?(line)
              puts "(Debug: Exit condition met)" if ENV["DEBUG"]
              break
            end

            next if line.nil? || line.strip.empty?

            puts "(Debug: Processing input: #{line.strip})" if ENV["DEBUG"]
            process_input(line.strip)
            puts "(Debug: Input processed successfully)" if ENV["DEBUG"]
          rescue Interrupt
            # Handle Ctrl-C
            if handle_interrupt
              break # Exit on double Ctrl-C
            end
            next # Continue on single Ctrl-C
          rescue SystemExit => e
            puts "A command tried to exit with code #{e.status}. Staying in interactive mode."
            puts "(Debug: SystemExit caught in main loop)" if ENV["DEBUG"]
          rescue => e
            puts "Error: #{e.message}"
            puts e.backtrace.first(5) if ENV["DEBUG"]
            puts "(Debug: Error handled, continuing loop)" if ENV["DEBUG"]
            # Continue the loop - don't let errors break the session
          end
        end

        puts "(Debug: Exited main loop)" if ENV["DEBUG"]
        save_history
        puts nesting_level > 0 ? "Exiting nested session..." : "Goodbye!"
      ensure
        # Restore previous session state
        if was_in_session
          ENV["THOR_INTERACTIVE_SESSION"] = "true"
          ENV["THOR_INTERACTIVE_LEVEL"] = nesting_level.to_s
        else
          ENV.delete("THOR_INTERACTIVE_SESSION")
          ENV.delete("THOR_INTERACTIVE_LEVEL")
        end
      end

      private

      def setup_completion
        Reline.completion_proc = proc do |text, preposing|
          complete_input(text, preposing)
        end
      end

      def handle_interrupt
        current_time = Time.now

        # Check for double Ctrl-C
        if @last_interrupt_time && @double_ctrl_c_timeout && (current_time - @last_interrupt_time) < @double_ctrl_c_timeout
          puts "\n(Interrupted twice - exiting)"
          @last_interrupt_time = nil # Reset for next time
          return true # Signal to exit
        end

        @last_interrupt_time = current_time

        # Single Ctrl-C behavior
        case @ctrl_c_behavior
        when :clear_prompt
          puts "^C"
          puts "(Press Ctrl-C again quickly or Ctrl-D to exit)"
        when :show_help
          puts "\n^C - Interrupt"
          puts "Press Ctrl-C again to exit, or type 'help' for commands"
        when :silent
          # Just clear the line, no message
          print "\r#{" " * 80}\r"
        else
          # Default behavior
          puts "^C"
        end

        false # Don't exit, just clear prompt
      end

      def show_welcome(nesting_level = 0)
        if nesting_level > 0
          puts "#{@thor_class.name} Interactive Shell (nested level #{nesting_level + 1})"
          puts "Type 'exit' to return to previous level, or 'help' for commands"
        else
          puts "#{@thor_class.name} Interactive Shell"
          puts "Type 'help' for available commands, 'exit' to quit"
        end
        puts
      end

      def load_history
        return unless File.exist?(@history_file)

        File.readlines(@history_file, chomp: true).each do |line|
          Reline::HISTORY << line
        end
      rescue => e
        # Ignore history loading errors
      end

      def save_history
        return unless Reline::HISTORY.size > 0

        File.write(@history_file, Reline::HISTORY.to_a.join("\n"))
      rescue => e
        # Ignore history saving errors
      end
    end
  end
end
