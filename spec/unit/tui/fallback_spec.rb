# frozen_string_literal: true

require "spec_helper"
require "thor/interactive/tui"

RSpec.describe "TUI fallback when ratatui_ruby is not installed" do
  let(:test_app) do
    klass = Class.new(Thor) do
      include Thor::Interactive::Command

      desc "hello", "Say hello"
      def hello
        puts "Hello!"
      end
    end
    klass.configure_interactive(ui_mode: :tui)
    klass
  end

  describe "Thor::Interactive::TUI.available?" do
    it "returns true when ratatui_ruby is installed" do
      expect(Thor::Interactive::TUI.available?).to be true
    end

    it "can be stubbed to simulate missing gem" do
      allow(Thor::Interactive::TUI).to receive(:available?).and_return(false)
      expect(Thor::Interactive::TUI.available?).to be false
    end
  end

  describe "command routing fallback" do
    it "falls back to Shell when TUI is not available" do
      # Stub TUI.available? to return false
      allow(Thor::Interactive::TUI).to receive(:available?).and_return(false)

      # Expect Shell to be instantiated instead of RatatuiShell
      shell_double = instance_double(Thor::Interactive::Shell)
      allow(shell_double).to receive(:start)
      allow(Thor::Interactive::Shell).to receive(:new).and_return(shell_double)

      # Capture the fallback warning
      expect {
        instance = test_app.new
        instance.interactive
      }.to output(/ratatui_ruby gem not found/).to_stderr
    end

    it "uses Shell when ui_mode is not :tui" do
      app = Class.new(Thor) do
        include Thor::Interactive::Command

        desc "hello", "Say hello"
        def hello
          puts "Hello!"
        end
      end
      # No ui_mode: :tui configured

      shell_double = instance_double(Thor::Interactive::Shell)
      allow(shell_double).to receive(:start)
      allow(Thor::Interactive::Shell).to receive(:new).and_return(shell_double)

      instance = app.new
      instance.interactive

      expect(Thor::Interactive::Shell).to have_received(:new)
    end

    it "uses RatatuiShell when TUI is available" do
      require "thor/interactive/tui/ratatui_shell"

      allow(Thor::Interactive::TUI).to receive(:available?).and_return(true)

      shell_double = instance_double(Thor::Interactive::TUI::RatatuiShell)
      allow(shell_double).to receive(:start)
      allow(Thor::Interactive::TUI::RatatuiShell).to receive(:new).and_return(shell_double)

      instance = test_app.new
      instance.interactive

      expect(Thor::Interactive::TUI::RatatuiShell).to have_received(:new)
    end
  end
end
