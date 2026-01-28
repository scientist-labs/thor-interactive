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
              break  # Exit on double Ctrl-C
            end
            next  # Continue on single Ctrl-C
            
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
        # Parse the command and check what we're completing
        parts = preposing.split(/\s+/)
        command = parts[0].sub(/^\//, '') if parts[0]
        
        # Get the Thor task if it exists
        task = @thor_class.tasks[command] if command
        
        # Check if we're likely completing a path
        if path_like?(text) || after_path_option?(preposing)
          complete_path(text)
        elsif text.start_with?('--') || text.start_with?('-')
          # Complete option names
          complete_option_names(task, text)
        else
          # Default to path completion for positional args that might be files
          # This helps with commands that take file arguments
          complete_path(text)
        end
      end
      
      def path_like?(text)
        # Check if text looks like a path
        text.match?(%r{^[~./]|/}) || text.match?(/\.(txt|rb|md|json|xml|yaml|yml|csv|log|html|css|js)$/i)
      end
      
      def after_path_option?(preposing)
        # Check if we're after a common file/path option
        preposing.match?(/(?:--file|--output|--input|--path|--dir|--directory|-f|-o|-i|-d)\s*$/)
      end
      
      def complete_path(text)
        return [] if text.nil?
        
        # Special case for empty text - show files in current directory
        if text.empty?
          matches = Dir.glob("*", File::FNM_DOTMATCH).select do |path|
            basename = File.basename(path)
            basename != '.' && basename != '..'
          end
          return format_path_completions(matches, text)
        end
        
        # Expand ~ to home directory for matching
        expanded = text.start_with?('~') ? File.expand_path(text) : text
        
        # Determine directory and prefix for matching
        if text.end_with?('/')
          # User typed a directory with trailing slash - show its contents
          dir = expanded
          prefix = ''
        elsif File.directory?(expanded) && !text.end_with?('/')
          # It's a directory without trailing slash - complete the directory name
          dir = File.dirname(expanded)
          prefix = File.basename(expanded)
        else
          # Completing a partial filename
          dir = File.dirname(expanded)
          prefix = File.basename(expanded)
        end
        
        # Get matching files/dirs
        pattern = File.join(dir, "#{prefix}*")
        matches = Dir.glob(pattern, File::FNM_DOTMATCH).select do |path|
          # Filter out . and .. entries
          basename = File.basename(path)
          basename != '.' && basename != '..'
        end
        
        format_path_completions(matches, text)
      rescue => e
        # If path completion fails, return empty array
        []
      end
      
      def format_path_completions(matches, original_text)
        # Format the completions based on how the user typed the path
        matches.map do |path|
          # Add trailing / for directories
          display_path = File.directory?(path) && !path.end_with?('/') ? "#{path}/" : path
          
          # Handle paths with spaces by escaping them
          display_path = display_path.gsub(' ', '\ ')
          
          # Return path as user would type it
          if original_text.start_with?('~')
            # Replace home directory with ~
            home = ENV['HOME']
            if display_path.start_with?(home)
              "~#{display_path[home.length..-1]}"
            else
              display_path.sub(ENV['HOME'], '~')
            end
          elsif original_text.start_with?('./')
            # Keep ./ prefix and make path relative
            if display_path.start_with?(Dir.pwd)
              rel_path = display_path.sub(/^#{Regexp.escape(Dir.pwd)}\//, '')
              "./#{rel_path}"
            else
              # Already relative, just ensure ./ prefix
              display_path.start_with?('./') ? display_path : "./#{File.basename(display_path)}"
            end
          elsif original_text.start_with?('/')
            # Absolute path - return as is
            display_path
          else
            # Relative path without ./ prefix
            # If the matched path is in current dir, just return the basename
            dir = File.dirname(display_path)
            if dir == '.' || display_path.start_with?('./')
              basename = File.basename(display_path)
              basename += '/' if File.directory?(display_path.gsub('\ ', ' ')) && !basename.end_with?('/')
              basename
            else
              display_path.sub(/^#{Regexp.escape(Dir.pwd)}\//, '')
            end
          end
        end.sort
      end
      
      def complete_option_names(task, text)
        return [] unless task && task.options
        
        # Get all option names (long and short forms)
        options = []
        task.options.each do |name, option|
          options << "--#{name}"
          if option.aliases
            # Aliases can be string or array
            aliases = option.aliases.is_a?(Array) ? option.aliases : [option.aliases]
            aliases.each { |a| options << a if a.start_with?('-') }
          end
        end
        
        # Filter by what user has typed
        options.select { |opt| opt.start_with?(text) }.sort
      end

      def process_input(input)
        # Handle completely empty input
        return if input.nil? || input.strip.empty?

        # Check if input starts with / for explicit command mode
        if input.strip.start_with?('/')
          # Explicit command mode: /command args
          handle_slash_command(input.strip[1..-1])
        elsif is_help_request?(input)
          # Special case: treat bare "help" as /help for convenience
          if input.strip.split.length == 1
            show_help
          else
            command_part = input.strip.split[1] 
            show_help(command_part)
          end
        else
          # Determine if this looks like a command or natural language
          command_word = input.strip.split(/\s+/, 2).first
          
          if thor_command?(command_word)
            # Looks like a command - handle it as a command (backward compatibility)
            handle_command(input.strip)
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
      end

      def handle_slash_command(command_input)
        return if command_input.empty?
        handle_command(command_input)
      end

      def handle_command(command_input)
        # Extract command and check if it's a single-text command
        command_word = command_input.split(/\s+/, 2).first
        
        if thor_command?(command_word)
          task = @thor_class.tasks[command_word]
          
          if task && single_text_command?(task) && !task.options.any?
            # Single text command without options - pass everything after command as one argument
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
          # Get the Thor task/command definition
          task = @thor_class.tasks[command]
          
          if task && task.options && !task.options.empty?
            # Parse options if the command has them defined
            result = parse_thor_options(args, task)
            return unless result # Parse failed, error already shown

            parsed_args, parsed_options = result

            # Set options on the Thor instance
            @thor_instance.options = Thor::CoreExt::HashWithIndifferentAccess.new(parsed_options)
            
            # Call with parsed arguments only (options are in the options hash)
            if @thor_instance.respond_to?(command)
              @thor_instance.send(command, *parsed_args)
            else
              @thor_instance.send(command, *parsed_args)
            end
          else
            # No options defined, use original behavior
            if @thor_instance.respond_to?(command)
              @thor_instance.send(command, *args)
            else
              @thor_instance.send(command, *args)
            end
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
      
      def parse_thor_options(args, task)
        # Convert args array to a format Thor's option parser expects
        remaining_args = []
        parsed_options = {}

        begin
          # Create a temporary parser using Thor's options
          parser = Thor::Options.new(task.options)

          if args.is_a?(Array)
            # Parse the options from the array
            parsed_options = parser.parse(args)
            remaining_args = parser.remaining
          else
            # Single string argument, split it first
            split_args = safe_parse_input(args) || args.split(/\s+/)
            parsed_options = parser.parse(split_args)
            remaining_args = parser.remaining
          end
        rescue Thor::Error => e
          # Show user-friendly error for option parsing failures (e.g. invalid numeric value)
          puts "Option error: #{e.message}"
          return nil
        end

        # Check for unknown options left in remaining args
        unknown = remaining_args.select { |a| a.start_with?('--') || (a.start_with?('-') && a.length > 1 && !a.match?(/^-\d/)) }
        unless unknown.empty?
          puts "Unknown option#{'s' if unknown.length > 1}: #{unknown.join(', ')}"
          puts "Run '/help #{task.name}' to see available options."
          return nil
        end

        [remaining_args, parsed_options]
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
      
      def handle_interrupt
        current_time = Time.now
        
        # Check for double Ctrl-C
        if @last_interrupt_time && @double_ctrl_c_timeout && (current_time - @last_interrupt_time) < @double_ctrl_c_timeout
          puts "\n(Interrupted twice - exiting)"
          @last_interrupt_time = nil  # Reset for next time
          return true  # Signal to exit
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
          print "\r#{' ' * 80}\r"
        else
          # Default behavior
          puts "^C"
        end
        
        false  # Don't exit, just clear prompt
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