# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Option parsing" do
  let(:app_with_options) do
    Class.new(Thor) do
      include Thor::Interactive::Command
      
      desc "process FILE", "Process a file"
      option :verbose, type: :boolean, aliases: "-v", desc: "Verbose output"
      option :format, type: :string, default: "json", desc: "Output format"
      option :limit, type: :numeric, desc: "Limit results"
      option :tags, type: :array, desc: "Tags to apply"
      option :config, type: :hash, desc: "Configuration options"
      def process(file)
        puts "Processing #{file}"
        puts "Verbose: #{options[:verbose]}" if options[:verbose]
        puts "Format: #{options[:format]}"
        puts "Limit: #{options[:limit]}" if options[:limit]
        puts "Tags: #{options[:tags].join(', ')}" if options[:tags]
        puts "Config: #{options[:config]}" if options[:config]
      end
      
      desc "simple", "Command without options"
      def simple(arg1, arg2 = nil)
        puts "Args: #{arg1}, #{arg2}"
      end
      
      desc "flag", "Command with boolean flag"
      option :enabled, type: :boolean, desc: "Enable feature"
      def flag
        puts "Enabled: #{options[:enabled]}"
      end
    end
  end
  
  describe "basic option parsing" do
    let(:shell) { Thor::Interactive::Shell.new(app_with_options) }
    
    it "parses boolean options" do
      output = capture_stdout do
        shell.send(:invoke_thor_command, "process", ["file.txt", "--verbose"])
      end
      
      expect(output).to include("Processing file.txt")
      expect(output).to include("Verbose: true")
    end
    
    it "parses short option aliases" do
      output = capture_stdout do
        shell.send(:invoke_thor_command, "process", ["file.txt", "-v"])
      end
      
      expect(output).to include("Verbose: true")
    end
    
    it "parses string options" do
      output = capture_stdout do
        shell.send(:invoke_thor_command, "process", ["file.txt", "--format", "xml"])
      end
      
      expect(output).to include("Format: xml")
    end
    
    it "parses string options with equals syntax" do
      output = capture_stdout do
        shell.send(:invoke_thor_command, "process", ["file.txt", "--format=yaml"])
      end
      
      expect(output).to include("Format: yaml")
    end
    
    it "parses numeric options" do
      output = capture_stdout do
        shell.send(:invoke_thor_command, "process", ["file.txt", "--limit", "10"])
      end
      
      expect(output).to include("Limit: 10")
    end
    
    it "parses array options" do
      output = capture_stdout do
        shell.send(:invoke_thor_command, "process", ["file.txt", "--tags", "important", "urgent"])
      end
      
      expect(output).to include("Tags: important, urgent")
    end
    
    it "parses hash options" do
      output = capture_stdout do
        shell.send(:invoke_thor_command, "process", ["file.txt", "--config", "key1:value1", "key2:value2"])
      end
      
      expect(output).to include("Config: {\"key1\"=>\"value1\", \"key2\"=>\"value2\"}")
    end
    
    it "handles multiple options" do
      output = capture_stdout do
        shell.send(:invoke_thor_command, "process", ["file.txt", "--verbose", "--format", "csv", "--limit", "5"])
      end
      
      expect(output).to include("Processing file.txt")
      expect(output).to include("Verbose: true")
      expect(output).to include("Format: csv")
      expect(output).to include("Limit: 5")
    end
    
    it "uses default values when options not provided" do
      output = capture_stdout do
        shell.send(:invoke_thor_command, "process", ["file.txt"])
      end
      
      expect(output).to include("Format: json")  # Default value
      expect(output).not_to include("Verbose:")  # Not set
      expect(output).not_to include("Limit:")    # Not set
    end
  end
  
  describe "commands without options" do
    let(:shell) { Thor::Interactive::Shell.new(app_with_options) }
    
    it "works normally for commands without options" do
      output = capture_stdout do
        shell.send(:invoke_thor_command, "simple", ["arg1", "arg2"])
      end
      
      expect(output).to include("Args: arg1, arg2")
    end
    
    it "doesn't parse options for commands that don't define them" do
      # Even if we pass option-like arguments, they should be treated as regular args
      output = capture_stdout do
        shell.send(:invoke_thor_command, "simple", ["--verbose", "--format=xml"])
      end
      
      expect(output).to include("Args: --verbose, --format=xml")
    end
  end
  
  describe "option parsing with natural language commands" do
    let(:shell) { Thor::Interactive::Shell.new(app_with_options) }
    
    it "still supports single-text commands with options" do
      # When we detect a single-text command, we should still parse options
      task = app_with_options.tasks["process"]
      allow(shell).to receive(:single_text_command?).with(task).and_return(false)
      
      output = capture_stdout do
        shell.send(:handle_command, "process file.txt --verbose --format xml")
      end
      
      expect(output).to include("Processing file.txt")
      expect(output).to include("Verbose: true")
      expect(output).to include("Format: xml")
    end
  end
  
  describe "error handling" do
    let(:shell) { Thor::Interactive::Shell.new(app_with_options) }
    
    it "handles invalid option values gracefully" do
      # Numeric option with non-numeric value
      output = capture_stdout do
        shell.send(:invoke_thor_command, "process", ["file.txt", "--limit", "not-a-number"])
      end

      # Should show a user-friendly error, not a stack trace
      expect(output).to include("Option error:")
      expect(output).to include("--limit")
      expect(output).not_to include("wrong number of arguments")
    end

    it "handles unknown options gracefully" do
      output = capture_stdout do
        shell.send(:invoke_thor_command, "process", ["file.txt", "--unknown-option"])
      end

      # Should warn about the unknown option, not blow up
      expect(output).to include("Unknown option")
      expect(output).to include("--unknown-option")
      expect(output).not_to include("wrong number of arguments")
    end
  end
  
  describe "edge cases" do
    let(:edge_app) do
      Class.new(Thor) do
        include Thor::Interactive::Command

        desc "topics [FILTER]", "List topics"
        option :summarize, type: :boolean
        option :format, type: :string
        def topics(filter = nil)
          puts "Filter: #{filter.inspect}"
          puts "Options: #{options.to_h.inspect}"
        end
      end
    end

    let(:shell) { Thor::Interactive::Shell.new(edge_app) }
    let(:task) { edge_app.tasks["topics"] }

    it "warns on unknown options" do
      output = capture_stdout do
        shell.send(:invoke_thor_command, "topics", ["--unknown-option"])
      end

      expect(output).to include("Unknown option")
      expect(output).to include("--unknown-option")
      expect(output).not_to include("Filter:")
    end

    it "warns when text args contain unknown option-like strings" do
      output = capture_stdout do
        result = shell.send(:parse_thor_options,
          ["The", "start", "--option", "the", "rest"],
          task
        )
        expect(result).to be_nil
      end

      expect(output).to include("Unknown option")
      expect(output).to include("--option")
    end

    it "parses valid options mixed with positional args" do
      args, options = shell.send(:parse_thor_options,
        ["AI", "topics", "--summarize"],
        task
      )

      expect(args).to include("AI")
      expect(options["summarize"]).to eq(true)
    end

    it "parses valid string option with value placed before args" do
      args, options = shell.send(:parse_thor_options,
        ["--format", "json", "AI"],
        task
      )

      expect(args).to eq(["AI"])
      expect(options["format"]).to eq("json")
    end

    it "parses valid string option with value placed after args" do
      args, options = shell.send(:parse_thor_options,
        ["AI", "--format", "json"],
        task
      )

      expect(args).to eq(["AI"])
      expect(options["format"]).to eq("json")
    end

    it "handles multiple unknown options" do
      output = capture_stdout do
        result = shell.send(:parse_thor_options,
          ["file.txt", "--foo", "--bar"],
          task
        )
        expect(result).to be_nil
      end

      expect(output).to include("Unknown options")
      expect(output).to include("--foo")
      expect(output).to include("--bar")
    end
  end

  describe "slash command format" do
    let(:shell) { Thor::Interactive::Shell.new(app_with_options) }
    
    it "parses options in slash commands" do
      output = capture_stdout do
        shell.send(:process_input, "/process file.txt --verbose --limit 10")
      end
      
      expect(output).to include("Processing file.txt")
      expect(output).to include("Verbose: true")
      expect(output).to include("Limit: 10")
    end
  end
  
  describe "option parsing internals" do
    let(:shell) { Thor::Interactive::Shell.new(app_with_options) }
    let(:task) { app_with_options.tasks["process"] }
    
    it "correctly separates options from arguments" do
      args, options = shell.send(:parse_thor_options, 
        ["file.txt", "--verbose", "--format", "xml", "extra_arg"], 
        task
      )
      
      expect(args).to eq(["file.txt", "extra_arg"])
      expect(options[:verbose]).to eq(true)
      expect(options[:format]).to eq("xml")
    end
    
    it "handles single string argument with options" do
      args, options = shell.send(:parse_thor_options,
        "file.txt --verbose",
        task
      )
      
      # When given a single string, it should be parsed
      expect(options[:verbose]).to eq(true)
    end
    
    it "returns nil when parsing fails" do
      # Create the shell first, then stub Thor::Options.new to force a parse error
      test_shell = shell

      allow(Thor::Options).to receive(:new).and_raise(Thor::Error, "Parse error")

      output = capture_stdout do
        result = test_shell.send(:parse_thor_options,
          ["file.txt", "--bad-option"],
          task
        )
        expect(result).to be_nil
      end

      expect(output).to include("Option error: Parse error")
    end
  end
  
  describe "backward compatibility" do
    let(:shell) { Thor::Interactive::Shell.new(app_with_options) }
    
    it "maintains compatibility with existing single-text commands" do
      # Create a method that expects a single text argument
      app_with_options.class_eval do
        desc "echo TEXT", "Echo text"
        def echo(text)
          puts "Echo: #{text}"
        end
      end
      
      output = capture_stdout do
        shell.send(:process_input, "/echo hello world this is text")
      end
      
      expect(output).to include("Echo: hello world this is text")
    end
    
    it "doesn't break natural language processing" do
      shell = Thor::Interactive::Shell.new(app_with_options, 
        default_handler: ->(input, instance) { puts "Natural: #{input}" }
      )
      
      output = capture_stdout do
        shell.send(:process_input, "this is natural language")
      end
      
      expect(output).to include("Natural: this is natural language")
    end
  end
end