# frozen_string_literal: true

require "shellwords"
require "thor"

class Thor
  module Interactive
    # Shared command dispatch logic used by both the Reline-based Shell
    # and the ratatui_ruby-based TUI shell.
    #
    # Includers must provide:
    #   @thor_class    - the Thor class
    #   @thor_instance - a persistent Thor instance
    #   @default_handler - optional proc for natural language input
    #   @merged_options  - merged configuration options
    module CommandDispatch
      EXIT_COMMANDS = %w[exit quit q].freeze

      def process_input(input)
        return if input.nil? || input.strip.empty?

        if input.strip.start_with?("/")
          handle_slash_command(input.strip[1..-1])
        elsif is_help_request?(input)
          if input.strip.split.length == 1
            show_help
          else
            command_part = input.strip.split[1]
            show_help(command_part)
          end
        else
          command_word = input.strip.split(/\s+/, 2).first

          if thor_command?(command_word)
            handle_command(input.strip)
          elsif @default_handler
            begin
              @default_handler.call(input, @thor_instance)
            rescue => e
              puts "Error in default handler: #{e.message}"
              puts "Input was: #{input}"
              puts "Try using /commands or type '/help' for available commands."
            end
          else
            puts "No default handler configured. Use /command for commands, or type '/help' for available commands."
          end
        end
      end

      def handle_slash_command(command_input)
        return if command_input.empty?
        handle_command(command_input)
      end

      def handle_command(command_input)
        command_word = command_input.split(/\s+/, 2).first

        if thor_command?(command_word)
          task = @thor_class.tasks[command_word]

          if task && single_text_command?(task) && !task.options.any?
            text_part = command_input.sub(/^#{Regexp.escape(command_word)}\s*/, "")
            if text_part.empty?
              invoke_thor_command(command_word, [])
            else
              invoke_thor_command(command_word, [text_part])
            end
          else
            args = safe_parse_input(command_input)
            if args && !args.empty?
              command = args.shift
              invoke_thor_command(command, args)
            else
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
        Shellwords.split(input)
      rescue ArgumentError
        nil
      end

      def parse_input(input)
        safe_parse_input(input) || []
      end

      def handle_unparseable_command(input, command_word)
        text_part = input.strip.sub(/^#{Regexp.escape(command_word)}\s*/, "")
        if text_part.empty?
          invoke_thor_command(command_word, [])
        else
          invoke_thor_command(command_word, [text_part])
        end
      end

      def single_text_command?(task)
        return false unless task

        method_name = task.name.to_sym
        if @thor_instance.respond_to?(method_name)
          method_obj = @thor_instance.method(method_name)
          param_count = method_obj.parameters.count { |type, _| type == :req }
          param_count == 1
        else
          false
        end
      rescue
        false
      end

      def is_help_request?(input)
        stripped = input.strip.downcase
        stripped == "help" || stripped.start_with?("help ")
      end

      def thor_command?(command)
        @thor_class.tasks.key?(command) ||
          @thor_class.subcommand_classes.key?(command) ||
          command == "help"
      end

      def invoke_thor_command(command, args)
        if command == "help"
          show_help(args.first)
        else
          task = @thor_class.tasks[command]

          if task && task.options && !task.options.empty?
            result = parse_thor_options(args, task)
            return unless result

            parsed_args, parsed_options = result

            @thor_instance.options = Thor::CoreExt::HashWithIndifferentAccess.new(parsed_options)

            if @thor_instance.respond_to?(command)
              @thor_instance.send(command, *parsed_args)
            else
              @thor_instance.send(command, *parsed_args)
            end
          else
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
        remaining_args = []
        parsed_options = {}

        begin
          parser = Thor::Options.new(task.options)

          if args.is_a?(Array)
            parsed_options = parser.parse(args)
            remaining_args = parser.remaining
          else
            split_args = safe_parse_input(args) || args.split(/\s+/)
            parsed_options = parser.parse(split_args)
            remaining_args = parser.remaining
          end
        rescue Thor::Error => e
          puts "Option error: #{e.message}"
          return nil
        end

        unknown = remaining_args.select { |a| a.start_with?("--") || (a.start_with?("-") && a.length > 1 && !a.match?(/^-\d/)) }
        unless unknown.empty?
          puts "Unknown option#{"s" if unknown.length > 1}: #{unknown.join(", ")}"
          puts "Run '/help #{task.name}' to see available options."
          return nil
        end

        [remaining_args, parsed_options]
      end

      def show_help(command = nil)
        if command && @thor_class.subcommand_classes.key?(command)
          subcommand_class = @thor_class.subcommand_classes[command]
          puts "Commands for '#{command}':"
          subcommand_class.tasks.each do |name, task|
            puts "  /#{command} #{name.ljust(15)} #{task.description}"
          end
          puts
        elsif command && @thor_class.tasks.key?(command)
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
        return true if line.nil?

        stripped = line.strip.downcase
        EXIT_COMMANDS.include?(stripped) || EXIT_COMMANDS.include?(stripped.sub(/^\//, ""))
      end

      # Completion methods

      def complete_input(text, preposing)
        full_line = preposing + text

        if full_line.start_with?("/")
          if preposing.strip == "/" || preposing.strip.empty?
            command_completions = complete_commands(text.sub(/^\//, ""))
            command_completions.map { |cmd| "/#{cmd}" }
          else
            complete_command_options(text, preposing)
          end
        else
          []
        end
      end

      def complete_commands(text)
        return [] if text.nil?

        command_names = @thor_class.tasks.keys + EXIT_COMMANDS + ["help"]
        command_names.select { |cmd| cmd.start_with?(text) }.sort
      end

      def complete_command_options(text, preposing)
        parts = preposing.split(/\s+/)
        command = parts[0].sub(/^\//, "") if parts[0]

        subcommand_class = @thor_class.subcommand_classes[command] if command
        if subcommand_class
          return complete_subcommand_args(subcommand_class, text, parts)
        end

        task = @thor_class.tasks[command] if command

        if path_like?(text) || after_path_option?(preposing)
          complete_path(text)
        elsif text.start_with?("--") || text.start_with?("-")
          complete_option_names(task, text)
        else
          complete_path(text)
        end
      end

      def complete_subcommand_args(subcommand_class, text, parts)
        if parts.length <= 1
          complete_subcommands(subcommand_class, text)
        else
          sub_cmd_name = parts[1]
          sub_task = subcommand_class.tasks[sub_cmd_name]

          if text.start_with?("--") || text.start_with?("-")
            complete_option_names(sub_task, text)
          else
            if parts.length == 2 && !text.empty?
              complete_subcommands(subcommand_class, text)
            else
              complete_path(text)
            end
          end
        end
      end

      def complete_subcommands(subcommand_class, text)
        return [] if text.nil?

        command_names = subcommand_class.tasks.keys
        command_names.select { |cmd| cmd.start_with?(text) }.sort
      end

      def path_like?(text)
        text.match?(%r{^[~./]|/}) || text.match?(/\.(txt|rb|md|json|xml|yaml|yml|csv|log|html|css|js)$/i)
      end

      def after_path_option?(preposing)
        preposing.match?(/(?:--file|--output|--input|--path|--dir|--directory|-f|-o|-i|-d)\s*$/)
      end

      def complete_path(text)
        return [] if text.nil?

        if text.empty?
          matches = Dir.glob("*", File::FNM_DOTMATCH).select do |path|
            basename = File.basename(path)
            basename != "." && basename != ".."
          end
          return format_path_completions(matches, text)
        end

        expanded = text.start_with?("~") ? File.expand_path(text) : text

        if text.end_with?("/")
          dir = expanded
          prefix = ""
        elsif File.directory?(expanded) && !text.end_with?("/")
          dir = File.dirname(expanded)
          prefix = File.basename(expanded)
        else
          dir = File.dirname(expanded)
          prefix = File.basename(expanded)
        end

        pattern = File.join(dir, "#{prefix}*")
        matches = Dir.glob(pattern, File::FNM_DOTMATCH).select do |path|
          basename = File.basename(path)
          basename != "." && basename != ".."
        end

        format_path_completions(matches, text)
      rescue => e
        []
      end

      def format_path_completions(matches, original_text)
        matches.map do |path|
          display_path = File.directory?(path) && !path.end_with?("/") ? "#{path}/" : path
          display_path = display_path.gsub(" ", '\ ')

          if original_text.start_with?("~")
            home = ENV["HOME"]
            if display_path.start_with?(home)
              "~#{display_path[home.length..-1]}"
            else
              display_path.sub(ENV["HOME"], "~")
            end
          elsif original_text.start_with?("./")
            if display_path.start_with?(Dir.pwd)
              rel_path = display_path.sub(/^#{Regexp.escape(Dir.pwd)}\//, "")
              "./#{rel_path}"
            else
              display_path.start_with?("./") ? display_path : "./#{File.basename(display_path)}"
            end
          elsif original_text.start_with?("/")
            display_path
          else
            dir = File.dirname(display_path)
            if dir == "." || display_path.start_with?("./")
              basename = File.basename(display_path)
              basename += "/" if File.directory?(display_path.gsub('\ ', " ")) && !basename.end_with?("/")
              basename
            else
              display_path.sub(/^#{Regexp.escape(Dir.pwd)}\//, "")
            end
          end
        end.sort
      end

      def complete_option_names(task, text)
        return [] unless task && task.options

        options = []
        task.options.each do |name, option|
          options << "--#{name}"
          if option.aliases
            aliases = option.aliases.is_a?(Array) ? option.aliases : [option.aliases]
            aliases.each { |a| options << a if a.start_with?("-") }
          end
        end

        options.select { |opt| opt.start_with?(text) }.sort
      end
    end
  end
end
