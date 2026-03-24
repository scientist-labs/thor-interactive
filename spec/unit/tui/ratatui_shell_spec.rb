# frozen_string_literal: true

require "spec_helper"
require "thor/interactive/tui"

RSpec.describe Thor::Interactive::TUI do
  describe ".available?" do
    it "returns true when ratatui_ruby is installed" do
      expect(described_class.available?).to be true
    end
  end
end

RSpec.describe "TUI shell routing" do
  # Use the test app from support
  let(:test_app) do
    Class.new(Thor) do
      include Thor::Interactive::Command

      desc "greet NAME", "Say hello"
      def greet(name)
        puts "Hello, #{name}!"
      end
    end
  end

  describe "configure_interactive with ui_mode: :tui" do
    it "stores ui_mode in interactive_options" do
      test_app.configure_interactive(ui_mode: :tui)
      expect(test_app.interactive_options[:ui_mode]).to eq(:tui)
    end
  end
end

# Only run RatatuiShell specs if ratatui_ruby is available
if Thor::Interactive::TUI.available?
  require "thor/interactive/tui/ratatui_shell"

  RSpec.describe Thor::Interactive::TUI::RatatuiShell do
    let(:thor_class) do
      Class.new(Thor) do
        desc "hello", "Say hello"
        def hello
          puts "Hello!"
        end

        desc "greet NAME", "Greet someone"
        def greet(name)
          puts "Hello, #{name}!"
        end
      end
    end

    describe "#initialize" do
      it "creates a shell with a Thor class" do
        shell = described_class.new(thor_class)
        expect(shell.thor_class).to eq(thor_class)
        expect(shell.thor_instance).to be_a(thor_class)
      end

      it "accepts custom prompt" do
        shell = described_class.new(thor_class, prompt: "test> ")
        expect(shell.prompt).to eq("test> ")
      end

      it "includes CommandDispatch" do
        shell = described_class.new(thor_class)
        expect(shell).to respond_to(:process_input)
        expect(shell).to respond_to(:complete_input)
        expect(shell).to respond_to(:show_help)
      end
    end

    describe "command dispatch integration" do
      let(:shell) { described_class.new(thor_class) }

      it "recognizes thor commands" do
        expect(shell.send(:thor_command?, "hello")).to be true
        expect(shell.send(:thor_command?, "greet")).to be true
        expect(shell.send(:thor_command?, "unknown")).to be false
      end

      it "completes commands" do
        completions = shell.send(:complete_commands, "he")
        expect(completions).to include("hello")
      end
    end

    describe "stdout capture" do
      let(:shell) { described_class.new(thor_class) }

      it "strips ANSI codes" do
        result = shell.send(:strip_ansi, "\e[31mred\e[0m text")
        expect(result).to eq("red text")
      end
    end
  end
end
