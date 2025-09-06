# frozen_string_literal: true

RSpec.describe "Shell Integration" do
  describe "state persistence" do
    let(:shell) { Thor::Interactive::Shell.new(StatefulTestApp) }

    it "maintains state between commands" do
      # Execute multiple commands and verify state is preserved
      output1 = capture_stdout { shell.send(:process_input, "count") }
      expect(output1.strip).to eq("Count: 1")

      output2 = capture_stdout { shell.send(:process_input, "count") }
      expect(output2.strip).to eq("Count: 2")

      output3 = capture_stdout { shell.send(:process_input, "status") }
      expect(output3.strip).to eq("Counter: 2, Items: 0")
    end

    it "maintains list state between commands" do
      capture_stdout { shell.send(:process_input, "add first") }
      capture_stdout { shell.send(:process_input, "add second") }
      
      output = capture_stdout { shell.send(:process_input, "list") }
      expect(output).to include("1. first")
      expect(output).to include("2. second")
    end

    it "resets state with reset command" do
      capture_stdout { shell.send(:process_input, "count") }
      capture_stdout { shell.send(:process_input, "count") }
      capture_stdout { shell.send(:process_input, "reset") }
      
      output = capture_stdout { shell.send(:process_input, "status") }
      expect(output.strip).to eq("Counter: 0, Items: 0")
    end

    it "clears items with clear command" do
      capture_stdout { shell.send(:process_input, "add test") }
      capture_stdout { shell.send(:process_input, "clear") }
      
      output = capture_stdout { shell.send(:process_input, "list") }
      expect(output.strip).to eq("No items")
    end
  end

  describe "default handler integration" do
    let(:shell) { Thor::Interactive::Shell.new(StatefulTestApp) }

    it "routes unrecognized input to default handler" do
      output = capture_stdout { shell.send(:process_input, "this is not a command") }
      expect(output.strip).to eq("Echo: this is not a command")
    end

    it "handles complex unrecognized input" do
      output = capture_stdout { shell.send(:process_input, "tell me about ruby programming") }
      expect(output.strip).to eq("Echo: tell me about ruby programming")
    end

    it "handles empty default handler input" do
      # Empty/whitespace input should be ignored, not sent to default handler
      output = capture_stdout { shell.send(:process_input, "   ") }
      expect(output.strip).to eq("")
    end
  end

  describe "mixed command workflows" do
    let(:shell) { Thor::Interactive::Shell.new(StatefulTestApp) }

    it "handles mix of known commands and default handler" do
      # Known command
      output1 = capture_stdout { shell.send(:process_input, "count") }
      expect(output1.strip).to eq("Count: 1")

      # Unknown command (goes to default handler)
      output2 = capture_stdout { shell.send(:process_input, "ask something") }
      expect(output2.strip).to eq("Echo: ask something")

      # Another known command
      output3 = capture_stdout { shell.send(:process_input, "status") }
      expect(output3.strip).to eq("Counter: 1, Items: 0")
    end

    it "maintains state across mixed interactions" do
      capture_stdout { shell.send(:process_input, "add item1") }
      capture_stdout { shell.send(:process_input, "some random text") }
      capture_stdout { shell.send(:process_input, "count") }
      capture_stdout { shell.send(:process_input, "more random text") }
      capture_stdout { shell.send(:process_input, "add item2") }

      output = capture_stdout { shell.send(:process_input, "status") }
      expect(output.strip).to eq("Counter: 1, Items: 2")
    end
  end

  describe "error handling workflows" do
    let(:simple_shell) { Thor::Interactive::Shell.new(SimpleTestApp) }

    it "recovers from command errors and continues" do
      # Cause an error
      error_output = capture_stdout { simple_shell.send(:process_input, "fail") }
      expect(error_output).to include("Error: Test error")

      # Verify shell continues working
      success_output = capture_stdout { simple_shell.send(:process_input, "hello Recovery") }
      expect(success_output.strip).to eq("Hello Recovery!")
    end

    it "handles argument errors gracefully" do
      # Missing argument
      error_output = capture_stdout { simple_shell.send(:process_input, "hello") }
      expect(error_output).to include("Thor Error")

      # Verify shell continues working
      success_output = capture_stdout { simple_shell.send(:process_input, "echo test") }
      expect(success_output.strip).to eq("Echo: test")
    end

    it "handles malformed input and continues" do
      # Malformed shell input (now handled gracefully)
      error_output = capture_stdout { simple_shell.send(:process_input, 'hello "unclosed') }
      expect(error_output).to include('Hello "unclosed!')

      # Verify shell continues working
      success_output = capture_stdout { simple_shell.send(:process_input, "hello World") }
      expect(success_output.strip).to eq("Hello World!")
    end
  end

  describe "help system integration" do
    let(:shell) { Thor::Interactive::Shell.new(StatefulTestApp) }

    it "shows help for all commands" do
      output = capture_stdout { shell.send(:process_input, "help") }
      
      expect(output).to include("Available commands:")
      expect(output).to include("count")
      expect(output).to include("add")
      expect(output).to include("list")
      expect(output).to include("Special commands:")
      expect(output).to include("exit/quit/q")
    end

    it "integrates with Thor's help system" do
      allow(StatefulTestApp).to receive(:command_help)
      
      shell.send(:process_input, "help count")
      
      expect(StatefulTestApp).to have_received(:command_help).with(anything, "count")
    end
  end

  describe "options and arguments integration" do
    let(:options_shell) { Thor::Interactive::Shell.new(OptionsTestApp) }

    it "handles basic commands" do
      output = capture_stdout { options_shell.send(:process_input, "greet Alice") }
      expect(output.strip).to eq("Hello Alice!")
    end

    it "handles commands with multiple arguments" do
      output = capture_stdout { options_shell.send(:process_input, "config database_url postgres://localhost") }
      expect(output.strip).to eq("Set database_url=postgres://localhost (local)")
    end

    # Note: Complex Thor option parsing (--flags) is not fully implemented
    # This is a limitation of the current simple implementation
  end

  describe "subcommand integration" do
    let(:subcommand_shell) { Thor::Interactive::Shell.new(SubcommandTestApp) }

    it "recognizes subcommands for completion" do
      expect(subcommand_shell.send(:thor_command?, "db")).to be true
      expect(subcommand_shell.send(:thor_command?, "server")).to be true
    end

    # Note: Thor subcommand execution is not fully implemented in this version
    # This would require more complex Thor integration beyond the current scope
  end

  describe "full session simulation" do
    let(:shell) { Thor::Interactive::Shell.new(StatefulTestApp) }

    it "simulates a complete interactive session" do
      # Build up state
      capture_stdout { shell.send(:process_input, "add task1") }
      capture_stdout { shell.send(:process_input, "add task2") }
      capture_stdout { shell.send(:process_input, "count") }
      capture_stdout { shell.send(:process_input, "count") }

      # Check current state
      status_output = capture_stdout { shell.send(:process_input, "status") }
      expect(status_output.strip).to eq("Counter: 2, Items: 2")

      # List items
      list_output = capture_stdout { shell.send(:process_input, "list") }
      expect(list_output).to include("1. task1")
      expect(list_output).to include("2. task2")

      # Use default handler
      echo_output = capture_stdout { shell.send(:process_input, "arbitrary user input") }
      expect(echo_output.strip).to eq("Echo: arbitrary user input")

      # Verify state persisted through default handler usage
      final_status = capture_stdout { shell.send(:process_input, "status") }
      expect(final_status.strip).to eq("Counter: 2, Items: 2")

      # Clean up
      capture_stdout { shell.send(:process_input, "clear") }
      capture_stdout { shell.send(:process_input, "reset") }

      # Verify cleanup
      final_output = capture_stdout { shell.send(:process_input, "status") }
      expect(final_output.strip).to eq("Counter: 0, Items: 0")
    end
  end

  describe "Thor::Interactive.start convenience method" do
    it "starts shell with given Thor class" do
      shell = double("shell")
      expect(Thor::Interactive::Shell).to receive(:new)
        .with(SimpleTestApp, {})
        .and_return(shell)
      expect(shell).to receive(:start)

      Thor::Interactive.start(SimpleTestApp)
    end

    it "passes options to shell" do
      handler = proc { |input, instance| puts "Custom: #{input}" }
      options = { prompt: "test> ", default_handler: handler }

      shell = double("shell")
      expect(Thor::Interactive::Shell).to receive(:new)
        .with(SimpleTestApp, options)
        .and_return(shell)
      expect(shell).to receive(:start)

      Thor::Interactive.start(SimpleTestApp, **options)
    end
  end
end