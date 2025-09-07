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
          line = Reline.readline(display_prompt, true)
          puts "(Debug: Got input: #{line.inspect})" if ENV["DEBUG"]
          
          if should_exit?(line)
            puts "(Debug: Exit condition met)" if ENV["DEBUG"]
            break
          end
          
          next if line.nil? || line.strip.empty?
          
          begin
            puts "(Debug: Processing input: #{line.strip})" if ENV["DEBUG"]
            process_input(line.strip)
            puts "(Debug: Input processed successfully)" if ENV["DEBUG"]
          rescue Interrupt
            puts "\n(Interrupted - press Ctrl+D or type 'exit' to quit)"
          rescue SystemExit => e
            puts "A command tried to exit with code #{e.status}. Staying in interactive mode."
            puts "(Debug: SystemExit caught in main loop)" if ENV["DEBUG"]
          rescue => e
            puts "Error in main loop: #{e.message}"
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
        # Handle completion for slash commands
        full_line = preposing + text
        
        if full_line.start_with?('/')
          # Command completion mode
          if preposing.strip == '/' || preposing.strip.empty?
            # Complete command names with / prefix
            command_completions = complete_commands(text.sub(/^\//, ''))
            command_completions.map { |cmd| "/#{cmd}" }
          else
            # Complete command arguments (basic implementation)
            complete_command_options(text, preposing)
          end
        else
          # Natural language mode - no completion for now
          []
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

        # Check if input starts with / for command mode
        if input.strip.start_with?('/')
          # Command mode: /command args
          command_input = input.strip[1..-1] # Remove leading /
          return if command_input.empty?
          
          # Extract command and check if it's a single-text command
          command_word = command_input.split(/\s+/, 2).first
          
          if thor_command?(command_word)
            task = @thor_class.tasks[command_word]
            
            if task && single_text_command?(task)
              # Single text command - pass everything after command as one argument
              text_part = command_input.sub(/^#{Regexp.escape(command_word)}\s*/, '')
              if text_part.empty?
                invoke_thor_command(command_word, [])
              else
                invoke_thor_command(command_word, [text_part])
              end
            else
              # Multi-argument command, use proper parsing
              args = safe_parse_input(command_input)
              if args && !args.empty?
                command = args.shift
                invoke_thor_command(command, args)
              else
                # Parsing failed, try simple split
                parts = command_input.split(/\s+/)
                command = parts.shift
                invoke_thor_command(command, parts)
              end
            end
          else
            puts "Unknown command: '#{command_word}'. Type '/help' for available commands."
          end
        elsif is_help_request?(input)
          # Special case: treat bare "help" as /help for convenience
          if input.strip.split.length == 1
            show_help
          else
            command_part = input.strip.split[1] 
            show_help(command_part)
          end
        elsif @default_handler
          # Natural language mode: send whole input to default handler
          begin
            @default_handler.call(input, @thor_instance)
          rescue => e
            puts "Error in default handler: #{e.message}"
            puts "Input was: #{input}"
            puts "Try using /commands or type '/help' for available commands."
          end
        else
          # No default handler, suggest using command mode
          puts "No default handler configured. Use /command for commands, or type '/help' for available commands."
        end
      end

      def safe_parse_input(input)
        # Try proper shell parsing first
        Shellwords.split(input)
      rescue ArgumentError
        # If parsing fails, return nil so caller can handle it
        nil
      end

      def parse_input(input)
        # Legacy method - kept for backward compatibility
        safe_parse_input(input) || []
      end

      def handle_unparseable_command(input, command_word)
        # For commands that failed shell parsing, try intelligent handling
        task = @thor_class.tasks[command_word]
        
        # Always try single text approach first for better natural language support
        text_part = input.strip.sub(/^#{Regexp.escape(command_word)}\s*/, '')
        if text_part.empty?
          invoke_thor_command(command_word, [])
        else
          invoke_thor_command(command_word, [text_part])
        end
      end

      def single_text_command?(task)
        # Heuristic: determine if this is likely a single text command
        return false unless task
        
        # Check the method signature to see how many parameters it expects
        method_name = task.name.to_sym
        if @thor_instance.respond_to?(method_name)
          method_obj = @thor_instance.method(method_name)
          param_count = method_obj.parameters.count { |type, _| type == :req }
          
          # Only single required parameter = likely text command
          param_count == 1
        else
          # Fallback for introspection issues
          false
        end
      rescue
        # If introspection fails, default to false (safer)
        false
      end

      def is_help_request?(input)
        # Check if input is a help request (help, ?, etc.)
        stripped = input.strip.downcase
        stripped == "help" || stripped.start_with?("help ")
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
      rescue SystemExit => e
        if e.status == 0
          puts "Command completed successfully (would have exited with code 0 in CLI mode)"
        else
          puts "Command failed with exit code #{e.status}"
        end
        puts "(Use 'exit' or Ctrl+D to exit the interactive session)" if ENV["DEBUG"]
      rescue Thor::Error => e
        puts "Thor Error: #{e.message}"
      rescue ArgumentError => e
        puts "Thor Error: #{e.message}"
        puts "Try: help #{command}" if thor_command?(command)
      rescue StandardError => e
        puts "Error: #{e.message}"
        puts "Command: #{command}, Args: #{args.inspect}" if ENV["DEBUG"]
      end

      def show_help(command = nil)
        if command && @thor_class.tasks.key?(command)
          @thor_class.command_help(Thor::Base.shell.new, command)
        else
          puts "Available commands (prefix with /):"
          @thor_class.tasks.each do |name, task|
            puts "  /#{name.ljust(19)} #{task.description}"
          end
          puts
          puts "Special commands:"
          puts "  /help [COMMAND]      Show help for command"
          puts "  /exit, /quit, /q     Exit the REPL"
          puts
          if @default_handler
            puts "Natural language mode:"
            puts "  Type anything without / to use default handler"
          else
            puts "Use /command syntax for all commands"
          end
          puts
          if ENV["DEBUG"]
            puts "Debug info:"
            puts "  Thor class: #{@thor_class.name}"
            puts "  Available tasks: #{@thor_class.tasks.keys.sort}"
            puts "  Instance methods: #{@thor_instance.methods.grep(/^[a-z]/).sort}" if @thor_instance
            puts
          end
        end
      end

      def should_exit?(line)
        return true if line.nil? # Ctrl+D
        
        stripped = line.strip.downcase
        # Handle both /exit and exit for convenience
        EXIT_COMMANDS.include?(stripped) || EXIT_COMMANDS.include?(stripped.sub(/^\//, ''))
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