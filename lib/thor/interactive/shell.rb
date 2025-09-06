# frozen_string_literal: true

require "reline"
require "shellwords"
require "thor"

class Thor
  module Interactive
    class Shell
      DEFAULT_PROMPT = "> "
      DEFAULT_HISTORY_FILE = "~/.thor_interactive_history"
      EXIT_COMMANDS = %w[exit quit q].freeze

      attr_reader :thor_class, :thor_instance, :prompt

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
        
        setup_completion
        load_history
      end

      def start
        # Track that we're in an interactive session
        was_in_session = ENV['THOR_INTERACTIVE_SESSION']
        nesting_level = ENV['THOR_INTERACTIVE_LEVEL'].to_i
        
        ENV['THOR_INTERACTIVE_SESSION'] = 'true'
        ENV['THOR_INTERACTIVE_LEVEL'] = (nesting_level + 1).to_s
        
        # Adjust prompt for nested sessions if configured
        display_prompt = @prompt
        if nesting_level > 0 && @merged_options[:nested_prompt_format]
          display_prompt = @merged_options[:nested_prompt_format] % [nesting_level + 1, @prompt]
        elsif nesting_level > 0
          display_prompt = "(#{nesting_level + 1}) #{@prompt}"
        end
        
        show_welcome(nesting_level)
        
        loop do
          line = Reline.readline(display_prompt, true)
          break if should_exit?(line)
          
          next if line.nil? || line.strip.empty?
          
          process_input(line.strip)
        rescue Interrupt
          puts "\n(Interrupted - press Ctrl+D or type 'exit' to quit)"
        rescue => e
          puts "Error: #{e.message}"
          puts e.backtrace.first(3) if ENV["DEBUG"]
        end
        
        save_history
        puts nesting_level > 0 ? "Exiting nested session..." : "Goodbye!"
        
      ensure
        # Restore previous session state
        if was_in_session
          ENV['THOR_INTERACTIVE_SESSION'] = 'true'
          ENV['THOR_INTERACTIVE_LEVEL'] = nesting_level.to_s
        else
          ENV.delete('THOR_INTERACTIVE_SESSION')
          ENV.delete('THOR_INTERACTIVE_LEVEL')
        end
      end

      private

      def setup_completion
        Reline.completion_proc = proc do |text, preposing|
          complete_input(text, preposing)
        end
      end

      def complete_input(text, preposing)
        # If we're at the start of the line, complete command names
        if preposing.strip.empty?
          complete_commands(text)
        else
          # Try to complete command options or let it fall back to file completion
          complete_command_options(text, preposing)
        end
      end

      def complete_commands(text)
        return [] if text.nil?
        
        command_names = @thor_class.tasks.keys + EXIT_COMMANDS + ["help"]
        command_names.select { |cmd| cmd.start_with?(text) }.sort
      end

      def complete_command_options(text, preposing)
        # Basic implementation - can be enhanced later
        # For now, just return empty array to let Reline handle file completion
        []
      end

      def process_input(input)
        # Handle completely empty input
        return if input.nil? || input.strip.empty?

        args = parse_input(input)
        return if args.empty?

        command = args.shift

        if thor_command?(command)
          invoke_thor_command(command, args)
        elsif @default_handler
          @default_handler.call(input, @thor_instance)
        else
          puts "Unknown command: '#{command}'. Type 'help' for available commands."
        end
      end

      def parse_input(input)
        Shellwords.split(input)
      rescue ArgumentError => e
        puts "Error parsing input: #{e.message}"
        []
      end

      def thor_command?(command)
        @thor_class.tasks.key?(command) || 
        @thor_class.subcommand_classes.key?(command) ||
        command == "help"
      end

      def invoke_thor_command(command, args)
        # Use the persistent instance to maintain state
        if command == "help"
          show_help(args.first)
        else
          # For simple commands, call directly for state persistence
          # For complex options/subcommands, this is a basic implementation
          if @thor_instance.respond_to?(command)
            @thor_instance.send(command, *args)
          else
            @thor_instance.invoke(command, args)
          end
        end
      rescue Thor::Error => e
        puts "Thor Error: #{e.message}"
      rescue ArgumentError => e
        puts "Thor Error: #{e.message}"
        puts "Try: help #{command}" if thor_command?(command)
      rescue StandardError => e
        puts "Error: #{e.message}"
      end

      def show_help(command = nil)
        if command && @thor_class.tasks.key?(command)
          @thor_class.command_help(Thor::Base.shell.new, command)
        else
          puts "Available commands:"
          @thor_class.tasks.each do |name, task|
            puts "  #{name.ljust(20)} #{task.description}"
          end
          puts
          puts "Special commands:"
          puts "  help [COMMAND]       Show help for command"
          puts "  exit/quit/q          Exit the REPL"
          puts
        end
      end

      def should_exit?(line)
        return true if line.nil? # Ctrl+D
        
        stripped = line.strip.downcase
        EXIT_COMMANDS.include?(stripped)
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