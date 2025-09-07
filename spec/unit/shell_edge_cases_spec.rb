# frozen_string_literal: true

# Tests for remaining edge cases and error paths in shell.rb

RSpec.describe Thor::Interactive::Shell do
  describe "slash command parsing edge cases" do
    let(:shell) { described_class.new(SimpleTestApp) }

    it "handles empty slash command" do
      output = capture_stdout do
        shell.send(:process_input, "/")
      end
      
      # Should handle gracefully (empty command after /)
      expect(output).to be_a(String)
    end

    it "handles slash command with only whitespace" do
      output = capture_stdout do
        shell.send(:process_input, "/   ")
      end
      
      # Should handle gracefully
      expect(output).to be_a(String)
    end

    it "handles parsing failure in slash commands" do
      # Command that would cause parsing issues
      output = capture_stdout do
        shell.send(:process_input, "/hello unclosed\"quote")
      end
      
      # Should still execute the command using fallback parsing
      expect(output).to include("Hello")
    end
  end

  describe "help request detection edge cases" do
    let(:shell) { described_class.new(SimpleTestApp) }

    it "detects help with arguments" do
      expect(shell.send(:is_help_request?, "help hello")).to be true
    end

    it "detects help case insensitive" do
      expect(shell.send(:is_help_request?, "HELP")).to be true
    end

    it "doesn't detect help in the middle of text" do
      expect(shell.send(:is_help_request?, "please help me")).to be false
    end

    it "handles help request with specific command" do
      output = capture_stdout do
        shell.send(:process_input, "help hello")
      end
      
      expect(output).to be_a(String)
    end
  end

  describe "error handling without default handler" do
    let(:no_handler_shell) { described_class.new(SimpleTestApp, {}) }

    it "provides helpful message for unknown commands" do
      output = capture_stdout do
        no_handler_shell.send(:process_input, "unknown")
      end
      
      expect(output).to include("No default handler configured")
    end

    it "suggests slash commands for unknown input" do
      output = capture_stdout do
        no_handler_shell.send(:process_input, "random text")
      end
      
      expect(output).to include("Use /command for commands")
    end
  end

  describe "completion with complex scenarios" do
    let(:shell) { described_class.new(SimpleTestApp) }

    it "handles completion when preposing contains slash" do
      completions = shell.send(:complete_input, "h", "/")
      expect(completions).to include("/hello")
    end

    it "handles completion with partial slash command" do
      completions = shell.send(:complete_input, "ell", "/h")
      expect(completions).to be_a(Array)
    end

    it "returns empty for natural language completion" do
      completions = shell.send(:complete_input, "word", "some text ")
      expect(completions).to be_empty
    end
  end

  describe "history management error conditions" do
    it "handles File.exist? returning false" do
      with_temp_history_file do |path|
        allow(File).to receive(:exist?).with(path).and_return(false)
        
        expect {
          described_class.new(SimpleTestApp, history_file: path)
        }.not_to raise_error
      end
    end

    it "handles empty history array" do
      with_temp_history_file do |path|
        allow(Reline::HISTORY).to receive(:size).and_return(0)
        
        test_shell = described_class.new(SimpleTestApp, history_file: path)
        
        expect { test_shell.send(:save_history) }.not_to raise_error
      end
    end
  end

  describe "command execution fallback paths" do
    it "handles command that doesn't respond_to? the method name" do
      # Create a Thor class with a task but no corresponding method
      broken_class = Class.new(Thor) do
        # Add task without method (unusual but possible)
        desc "broken", "Broken command"
        # No actual method defined
      end
      
      broken_shell = described_class.new(broken_class)
      
      output = capture_stdout do
        broken_shell.send(:invoke_thor_command, "broken", [])
      end
      
      expect(output).to include("Error:")
    end
  end

  describe "environment variable edge cases" do
    it "handles missing THOR_INTERACTIVE_LEVEL" do
      ENV.delete('THOR_INTERACTIVE_LEVEL')
      
      expect {
        described_class.new(SimpleTestApp)
      }.not_to raise_error
    end

    it "handles malformed THOR_INTERACTIVE_LEVEL" do
      ENV['THOR_INTERACTIVE_LEVEL'] = 'not_a_number'
      
      expect {
        described_class.new(SimpleTestApp)
      }.not_to raise_error
      
      ENV.delete('THOR_INTERACTIVE_LEVEL')
    end
  end

  describe "Thor class without interactive_options" do
    let(:plain_thor_class) { Class.new(Thor) { desc "test", "test"; def test; puts "test"; end } }
    
    it "works with Thor classes that don't have interactive_options method" do
      expect {
        described_class.new(plain_thor_class)
      }.not_to raise_error
    end

    it "processes commands correctly without interactive_options" do
      plain_shell = described_class.new(plain_thor_class)
      
      output = capture_stdout do
        plain_shell.send(:process_input, "/test")
      end
      
      expect(output.strip).to eq("test")
    end
  end
end