# frozen_string_literal: true

RSpec.describe Thor::Interactive::Shell do
  let(:shell) { described_class.new(SimpleTestApp) }

  describe "#initialize" do
    it "creates a shell with a Thor class" do
      expect(shell.thor_class).to eq(SimpleTestApp)
      expect(shell.thor_instance).to be_a(SimpleTestApp)
    end

    it "accepts custom prompt" do
      custom_shell = described_class.new(SimpleTestApp, prompt: "custom> ")
      expect(custom_shell.prompt).to eq("custom> ")
    end

    it "accepts default handler" do
      handler = proc { |input, instance| puts "Custom: #{input}" }
      custom_shell = described_class.new(SimpleTestApp, default_handler: handler)
      
      output = capture_stdout do
        custom_shell.send(:process_input, "unknown command")
      end
      
      expect(output).to include("Custom: unknown command")
    end

    it "sets up completion" do
      # Just verify the shell was created without error
      expect(shell.thor_class).to eq(SimpleTestApp)
    end
  end

  describe "#process_input" do
    it "executes known Thor commands" do
      output = capture_stdout do
        shell.send(:process_input, "hello World")
      end
      
      expect(output.strip).to eq("Hello World!")
    end

    it "handles commands with multiple arguments" do
      output = capture_stdout do
        shell.send(:process_input, "echo one two three")
      end
      
      expect(output.strip).to eq("Echo: one two three")
    end

    it "handles empty input gracefully" do
      expect {
        shell.send(:process_input, "")
      }.not_to raise_error
    end

    it "handles malformed shell input gracefully" do
      output = capture_stdout do
        shell.send(:process_input, 'hello "unclosed quote')
      end
      
      # Should now handle gracefully and execute the command
      expect(output).to include('Hello "unclosed quote!')
    end

    it "shows error message for unknown commands without default handler" do
      output = capture_stdout do
        shell.send(:process_input, "unknown_command")
      end
      
      expect(output).to include("Use /command for commands")
    end

    it "handles Thor errors gracefully" do
      output = capture_stdout do
        shell.send(:process_input, "fail")
      end
      
      expect(output).to include("Error: Test error")
    end

    it "handles argument errors gracefully" do
      output = capture_stdout do
        shell.send(:process_input, "hello") # missing required argument
      end
      
      expect(output).to include("Thor Error")
    end
  end

  describe "#complete_commands" do
    it "returns matching command names" do
      completions = shell.send(:complete_commands, "h")
      expect(completions).to include("hello")
      expect(completions).not_to include("echo")
    end

    it "returns all commands for empty input" do
      completions = shell.send(:complete_commands, "")
      expect(completions).to include("hello", "echo", "help", "exit", "quit", "q")
    end

    it "returns empty array for non-matching input" do
      completions = shell.send(:complete_commands, "xyz")
      expect(completions).to be_empty
    end

    it "includes exit commands" do
      completions = shell.send(:complete_commands, "e")
      expect(completions).to include("exit", "echo")
    end
  end

  describe "#thor_command?" do
    it "recognizes Thor commands" do
      expect(shell.send(:thor_command?, "hello")).to be true
      expect(shell.send(:thor_command?, "echo")).to be true
    end

    it "recognizes help command" do
      expect(shell.send(:thor_command?, "help")).to be true
    end

    it "doesn't recognize unknown commands" do
      expect(shell.send(:thor_command?, "unknown")).to be false
    end
  end

  describe "#should_exit?" do
    it "recognizes exit commands" do
      expect(shell.send(:should_exit?, "exit")).to be true
      expect(shell.send(:should_exit?, "quit")).to be true
      expect(shell.send(:should_exit?, "q")).to be true
      expect(shell.send(:should_exit?, "EXIT")).to be true
    end

    it "recognizes Ctrl+D (nil input)" do
      expect(shell.send(:should_exit?, nil)).to be true
    end

    it "doesn't exit on regular commands" do
      expect(shell.send(:should_exit?, "hello")).to be false
    end
  end

  describe "#show_help" do
    it "shows general help without arguments" do
      output = capture_stdout do
        shell.send(:show_help)
      end
      
      expect(output).to include("Available commands (prefix with /):")
      expect(output).to include("hello")
      expect(output).to include("echo")
      expect(output).to include("Special commands:")
    end

    it "shows specific command help with argument" do
      # Mock Thor's command_help method
      allow(SimpleTestApp).to receive(:command_help)
      
      shell.send(:show_help, "hello")
      
      expect(SimpleTestApp).to have_received(:command_help)
    end
  end

  describe "history management" do
    it "loads history from file when it exists" do
      with_temp_history_file do |path|
        File.write(path, "command1\ncommand2\n")
        
        expect(File).to receive(:exist?).with(path).and_return(true)
        expect(File).to receive(:readlines).with(path, chomp: true).and_return(["command1", "command2"])
        
        described_class.new(SimpleTestApp, history_file: path)
        
        expect(Reline::HISTORY).to have_received(:<<).with("command1")
        expect(Reline::HISTORY).to have_received(:<<).with("command2")
      end
    end

    it "handles missing history file gracefully" do
      with_temp_history_file do |path|
        expect(File).to receive(:exist?).with(path).and_return(false)
        
        expect {
          described_class.new(SimpleTestApp, history_file: path)
        }.not_to raise_error
      end
    end

    it "saves history on exit" do
      with_temp_history_file do |path|
        allow(Reline::HISTORY).to receive(:to_a).and_return(["cmd1", "cmd2"])
        allow(Reline::HISTORY).to receive(:size).and_return(2)  # Override global mock
        allow(File).to receive(:write)
        
        test_shell = described_class.new(SimpleTestApp, history_file: path)
        test_shell.send(:save_history)
        
        expect(File).to have_received(:write).with(path, "cmd1\ncmd2")
      end
    end
  end
end