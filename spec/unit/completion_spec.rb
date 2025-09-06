# frozen_string_literal: true

RSpec.describe "Completion System" do
  let(:shell) { Thor::Interactive::Shell.new(OptionsTestApp) }

  describe "command completion" do
    it "completes command names" do
      completions = shell.send(:complete_commands, "g")
      expect(completions).to include("greet")
    end

    it "completes partial matches" do
      completions = shell.send(:complete_commands, "con")
      expect(completions).to include("config")
    end

    it "returns all commands for empty string" do
      completions = shell.send(:complete_commands, "")
      expected_commands = OptionsTestApp.tasks.keys + Thor::Interactive::Shell::EXIT_COMMANDS
      
      expect(completions).to include(*expected_commands)
    end

    it "returns empty array for no matches" do
      completions = shell.send(:complete_commands, "nonexistent")
      expect(completions).to be_empty
    end

    it "is case sensitive" do
      completions = shell.send(:complete_commands, "G")
      expect(completions).to be_empty
    end

    it "includes exit commands" do
      completions = shell.send(:complete_commands, "e")
      expect(completions).to include("exit")
    end

    it "sorts results" do
      # Add more commands starting with 'c' to test sorting
      test_class = Class.new(Thor) do
        desc "cat", "Cat command"
        def cat; end
        
        desc "copy", "Copy command" 
        def copy; end
        
        desc "create", "Create command"
        def create; end
      end
      
      test_shell = Thor::Interactive::Shell.new(test_class)
      completions = test_shell.send(:complete_commands, "c")
      
      expect(completions).to eq(completions.sort)
    end
  end

  describe "completion integration" do
    it "sets up Reline completion proc" do
      # Just verify completion setup doesn't raise an error
      expect { Thor::Interactive::Shell.new(SimpleTestApp) }.not_to raise_error
    end

    it "completion proc handles command completion" do
      # Get the completion proc that was set
      completion_proc = nil
      allow(Reline).to receive(:completion_proc=) do |proc|
        completion_proc = proc
      end
      
      # Create a new shell to capture the proc
      Thor::Interactive::Shell.new(SimpleTestApp)
      
      # Test the completion proc
      completions = completion_proc.call("h", "")
      expect(completions).to include("hello")
    end

    it "completion proc handles empty preposing" do
      completion_proc = nil
      allow(Reline).to receive(:completion_proc=) do |proc|
        completion_proc = proc
      end
      
      Thor::Interactive::Shell.new(SimpleTestApp)
      
      completions = completion_proc.call("e", "")
      expect(completions).to include("echo", "exit")
    end

    it "completion proc returns empty for options (basic implementation)" do
      completion_proc = nil
      allow(Reline).to receive(:completion_proc=) do |proc|
        completion_proc = proc
      end
      
      Thor::Interactive::Shell.new(OptionsTestApp)
      
      # When there's preposing text, it should return empty (for now)
      completions = completion_proc.call("--", "greet alice ")
      expect(completions).to be_empty
    end
  end

  describe "subcommand completion" do
    let(:subcommand_shell) { Thor::Interactive::Shell.new(SubcommandTestApp) }

    it "completes main commands" do
      completions = subcommand_shell.send(:complete_commands, "d")
      expect(completions).to include("db")
    end

    it "completes server commands" do
      completions = subcommand_shell.send(:complete_commands, "s")
      expect(completions).to include("server")
    end

    it "includes subcommands in thor_command? check" do
      expect(subcommand_shell.send(:thor_command?, "db")).to be true
      expect(subcommand_shell.send(:thor_command?, "server")).to be true
    end
  end

  describe "completion edge cases" do
    it "handles nil input gracefully" do
      expect {
        shell.send(:complete_commands, nil)
      }.not_to raise_error
    end

    it "handles special characters in input" do
      completions = shell.send(:complete_commands, "@#$%")
      expect(completions).to be_empty
    end

    it "handles very long input" do
      long_input = "a" * 1000
      completions = shell.send(:complete_commands, long_input)
      expect(completions).to be_empty
    end

    it "handles unicode input" do
      completions = shell.send(:complete_commands, "café")
      expect(completions).to be_empty
    end
  end
end