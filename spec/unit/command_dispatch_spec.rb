# frozen_string_literal: true

require "spec_helper"

# A minimal host class that includes CommandDispatch for testing.
# This isolates command dispatch logic from both Shell and RatatuiShell.
class CommandDispatchTestHost
  include Thor::Interactive::CommandDispatch

  attr_reader :thor_class, :thor_instance
  attr_accessor :default_handler

  def initialize(thor_class, default_handler: nil)
    @thor_class = thor_class
    @thor_instance = thor_class.new
    @default_handler = default_handler
    @merged_options = {}
  end
end

RSpec.describe Thor::Interactive::CommandDispatch do
  let(:thor_class) { SimpleTestApp }
  let(:host) { CommandDispatchTestHost.new(thor_class) }

  describe "#process_input" do
    it "handles nil input" do
      expect { host.process_input(nil) }.not_to raise_error
    end

    it "handles empty input" do
      expect { host.process_input("") }.not_to raise_error
      expect { host.process_input("   ") }.not_to raise_error
    end

    it "routes slash commands" do
      output = capture_output { host.process_input("/hello world") }
      expect(output).to include("Hello world!")
    end

    it "routes help requests" do
      output = capture_output { host.process_input("help") }
      expect(output).to include("Available commands")
    end

    it "routes help with command argument" do
      output = capture_output { host.process_input("help hello") }
      expect(output).to include("hello")
    end

    it "routes recognized commands without slash" do
      output = capture_output { host.process_input("hello world") }
      expect(output).to include("Hello world!")
    end

    it "uses default handler for unrecognized input" do
      handler_called_with = nil
      host.default_handler = proc { |input, _instance| handler_called_with = input }
      host.process_input("some natural language")
      expect(handler_called_with).to eq("some natural language")
    end

    it "shows message when no default handler for unknown input" do
      output = capture_output { host.process_input("unknown stuff") }
      expect(output).to include("No default handler configured")
    end

    it "handles default handler errors gracefully" do
      host.default_handler = proc { |_input, _instance| raise "boom" }
      output = capture_output { host.process_input("trigger error") }
      expect(output).to include("Error in default handler")
    end
  end

  describe "#handle_slash_command" do
    it "delegates to handle_command" do
      output = capture_output { host.handle_slash_command("hello world") }
      expect(output).to include("Hello world!")
    end

    it "does nothing for empty input" do
      expect { host.handle_slash_command("") }.not_to raise_error
    end
  end

  describe "#safe_parse_input" do
    it "splits shell-style input" do
      expect(host.safe_parse_input('hello "world wide"')).to eq(["hello", "world wide"])
    end

    it "returns nil for unparseable input" do
      expect(host.safe_parse_input('hello "unclosed')).to be_nil
    end
  end

  describe "#parse_input" do
    it "returns empty array for unparseable input" do
      expect(host.parse_input('hello "unclosed')).to eq([])
    end
  end

  describe "#single_text_command?" do
    it "returns true for commands with one required param" do
      task = thor_class.tasks["hello"]
      expect(host.single_text_command?(task)).to be true
    end

    it "returns false for nil task" do
      expect(host.single_text_command?(nil)).to be false
    end
  end

  describe "#is_help_request?" do
    it "detects bare help" do
      expect(host.is_help_request?("help")).to be true
    end

    it "detects help with argument" do
      expect(host.is_help_request?("help hello")).to be true
    end

    it "is case insensitive" do
      expect(host.is_help_request?("HELP")).to be true
    end

    it "does not match help in middle of text" do
      expect(host.is_help_request?("need help")).to be false
    end
  end

  describe "#thor_command?" do
    it "recognizes known commands" do
      expect(host.thor_command?("hello")).to be true
      expect(host.thor_command?("echo")).to be true
    end

    it "recognizes help" do
      expect(host.thor_command?("help")).to be true
    end

    it "does not recognize unknown commands" do
      expect(host.thor_command?("nope")).to be false
    end
  end

  describe "#should_exit?" do
    it "exits on nil (Ctrl+D)" do
      expect(host.should_exit?(nil)).to be true
    end

    it "exits on exit commands" do
      %w[exit quit q].each do |cmd|
        expect(host.should_exit?(cmd)).to be true
      end
    end

    it "exits on slash-prefixed exit commands" do
      expect(host.should_exit?("/exit")).to be true
      expect(host.should_exit?("/quit")).to be true
    end

    it "does not exit on regular commands" do
      expect(host.should_exit?("hello")).to be false
      expect(host.should_exit?("exit_mode")).to be false
    end
  end

  describe "#invoke_thor_command" do
    it "invokes a simple command" do
      output = capture_output { host.invoke_thor_command("hello", ["world"]) }
      expect(output).to include("Hello world!")
    end

    it "invokes help" do
      output = capture_output { host.invoke_thor_command("help", []) }
      expect(output).to include("Available commands")
    end

    it "invokes help for specific command" do
      output = capture_output { host.invoke_thor_command("help", ["hello"]) }
      expect(output).to include("hello")
    end

    it "handles SystemExit gracefully" do
      # fail command raises StandardError, not SystemExit, but let's test the path
      output = capture_output { host.invoke_thor_command("fail", []) }
      expect(output).to include("Error:")
    end

    it "handles ArgumentError for wrong arg count" do
      output = capture_output { host.invoke_thor_command("hello", []) }
      expect(output).to include("Error") | include("wrong number")
    end
  end

  describe "#show_help" do
    it "shows general help" do
      output = capture_output { host.show_help }
      expect(output).to include("Available commands")
      expect(output).to include("/hello")
      expect(output).to include("/exit")
    end

    it "shows help for a specific command" do
      output = capture_output { host.show_help("hello") }
      expect(output).to include("hello")
    end

    it "shows command syntax for unknown command" do
      output = capture_output { host.show_help }
      expect(output).to include("Use /command syntax")
    end

    context "with default handler" do
      let(:host) do
        CommandDispatchTestHost.new(thor_class, default_handler: proc { |i, _| })
      end

      it "shows natural language mode info" do
        output = capture_output { host.show_help }
        expect(output).to include("Natural language mode")
      end
    end
  end

  context "with subcommands" do
    let(:host) { CommandDispatchTestHost.new(SubcommandTestApp) }

    describe "#thor_command?" do
      it "recognizes subcommand groups" do
        expect(host.thor_command?("db")).to be true
        expect(host.thor_command?("server")).to be true
      end
    end

    describe "#show_help for subcommand" do
      it "lists subcommand actions" do
        output = capture_output { host.show_help("db") }
        expect(output).to include("create")
        expect(output).to include("drop")
      end
    end
  end

  context "with options" do
    let(:host) { CommandDispatchTestHost.new(OptionsTestApp) }

    describe "#parse_thor_options" do
      it "parses boolean options" do
        task = OptionsTestApp.tasks["greet"]
        result = host.parse_thor_options(["--loud", "Alice"], task)
        args, opts = result
        expect(opts["loud"]).to be true
        expect(args).to include("Alice")
      end

      it "parses numeric options" do
        task = OptionsTestApp.tasks["greet"]
        result = host.parse_thor_options(["--times", "3", "Alice"], task)
        args, opts = result
        expect(opts["times"]).to eq(3)
      end

      it "returns nil on parse error" do
        task = OptionsTestApp.tasks["greet"]
        output = capture_output do
          result = host.parse_thor_options(["--times", "notanumber", "Alice"], task)
          expect(result).to be_nil
        end
        expect(output).to include("Option error")
      end

      it "warns on unknown options" do
        task = OptionsTestApp.tasks["greet"]
        output = capture_output do
          result = host.parse_thor_options(["--unknown", "Alice"], task)
          expect(result).to be_nil
        end
        expect(output).to include("Unknown option")
      end
    end
  end

  describe "completion" do
    describe "#complete_input" do
      it "completes slash commands" do
        results = host.complete_input("/hel", "/")
        expect(results).to include("/hello")
        expect(results).to include("/help")
      end

      it "returns empty for non-slash input" do
        results = host.complete_input("hel", "")
        expect(results).to eq([])
      end
    end

    describe "#complete_commands" do
      it "matches prefix" do
        expect(host.complete_commands("he")).to include("hello")
        expect(host.complete_commands("he")).to include("help")
      end

      it "returns all for empty string" do
        all = host.complete_commands("")
        expect(all).to include("hello", "echo", "exit", "quit", "help")
      end

      it "returns empty for nil" do
        expect(host.complete_commands(nil)).to eq([])
      end

      it "returns sorted results" do
        results = host.complete_commands("")
        expect(results).to eq(results.sort)
      end
    end

    describe "#complete_option_names" do
      let(:host) { CommandDispatchTestHost.new(OptionsTestApp) }

      it "completes long options" do
        task = OptionsTestApp.tasks["greet"]
        results = host.complete_option_names(task, "--l")
        expect(results).to include("--loud")
      end

      it "completes all options for --" do
        task = OptionsTestApp.tasks["greet"]
        results = host.complete_option_names(task, "--")
        expect(results).to include("--loud", "--times")
      end

      it "returns empty for nil task" do
        expect(host.complete_option_names(nil, "--")).to eq([])
      end
    end

    describe "#path_like?" do
      it "detects absolute paths" do
        expect(host.path_like?("/usr/bin")).to be true
      end

      it "detects relative paths" do
        expect(host.path_like?("./foo")).to be true
      end

      it "detects home paths" do
        expect(host.path_like?("~/docs")).to be true
      end

      it "detects file extensions" do
        expect(host.path_like?("file.rb")).to be true
        expect(host.path_like?("data.json")).to be true
      end

      it "returns false for plain text" do
        expect(host.path_like?("hello")).to be false
      end
    end

    describe "#after_path_option?" do
      it "detects file options" do
        expect(host.after_path_option?("--file ")).to be true
        expect(host.after_path_option?("-f ")).to be true
      end

      it "returns false for non-file options" do
        expect(host.after_path_option?("--verbose ")).to be false
      end
    end
  end

  # Helper to capture stdout output
  def capture_output(&block)
    output = StringIO.new
    old_stdout = $stdout
    $stdout = output
    block.call
    output.string
  ensure
    $stdout = old_stdout
  end
end
