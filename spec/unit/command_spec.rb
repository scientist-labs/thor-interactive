# frozen_string_literal: true

RSpec.describe Thor::Interactive::Command do
  let(:test_class) do
    Class.new(Thor) do
      include Thor::Interactive::Command
      
      desc "test", "A test command"
      def test
        puts "Test executed"
      end
    end
  end

  describe "when included" do
    it "adds the interactive command" do
      expect(test_class.tasks.keys).to include("interactive")
    end

    it "adds interactive command with proper description" do
      task = test_class.tasks["interactive"]
      expect(task.description).to eq("Start an interactive REPL for this application")
    end

    it "adds interactive command with options" do
      task = test_class.tasks["interactive"]
      expect(task.options.keys).to include(:prompt, :history_file)
    end

    it "extends the class with ClassMethods" do
      expect(test_class).to respond_to(:configure_interactive)
      expect(test_class).to respond_to(:interactive_options)
    end
  end

  describe ".configure_interactive" do
    it "stores interactive options" do
      test_class.configure_interactive(prompt: "test> ", custom_option: "value")
      
      expect(test_class.interactive_options[:prompt]).to eq("test> ")
      expect(test_class.interactive_options[:custom_option]).to eq("value")
    end

    it "merges multiple configurations" do
      test_class.configure_interactive(prompt: "first> ")
      test_class.configure_interactive(history_file: "~/.test")
      
      options = test_class.interactive_options
      expect(options[:prompt]).to eq("first> ")
      expect(options[:history_file]).to eq("~/.test")
    end
  end

  describe ".interactive_options" do
    it "returns empty hash by default" do
      fresh_class = Class.new(Thor) do
        include Thor::Interactive::Command
      end
      
      expect(fresh_class.interactive_options).to eq({})
    end

    it "persists across multiple accesses" do
      test_class.configure_interactive(test: "value")
      
      expect(test_class.interactive_options).to eq(test_class.interactive_options)
    end
  end

  describe "#interactive" do
    let(:instance) { test_class.new }

    before do
      # Mock the Thor options method
      allow(instance).to receive(:options).and_return({})
    end

    it "creates and starts a shell with the class" do
      shell = double("shell")
      expect(Thor::Interactive::Shell).to receive(:new)
        .with(test_class, {})
        .and_return(shell)
      expect(shell).to receive(:start)
      
      instance.interactive
    end

    it "passes configured options to shell" do
      test_class.configure_interactive(prompt: "configured> ")
      
      shell = double("shell")
      expect(Thor::Interactive::Shell).to receive(:new)
        .with(test_class, hash_including(prompt: "configured> "))
        .and_return(shell)
      expect(shell).to receive(:start)
      
      instance.interactive
    end

    it "overrides configured options with command-line options" do
      test_class.configure_interactive(prompt: "configured> ")
      allow(instance).to receive(:options).and_return({
        "prompt" => "override> ",
        "history_file" => "~/.override"
      })
      
      shell = double("shell")
      expect(Thor::Interactive::Shell).to receive(:new)
        .with(test_class, hash_including(
          prompt: "override> ",
          history_file: "~/.override"
        ))
        .and_return(shell)
      expect(shell).to receive(:start)
      
      instance.interactive
    end
  end

  describe "integration with StatefulTestApp" do
    it "maintains configured options" do
      expect(StatefulTestApp.interactive_options[:prompt]).to eq("test> ")
      expect(StatefulTestApp.interactive_options[:default_handler]).to be_a(Proc)
    end

    it "default handler works correctly" do
      handler = StatefulTestApp.interactive_options[:default_handler]
      instance = StatefulTestApp.new
      
      output = capture_stdout do
        handler.call("test input", instance)
      end
      
      expect(output).to include("Echo: test input")
    end
  end

  describe "CLI integration" do
    it "can be called from command line interface" do
      # Simulate Thor's start method
      shell = double("shell")
      allow(Thor::Interactive::Shell).to receive(:new).and_return(shell)
      allow(shell).to receive(:start)
      
      test_class.start(["interactive"])
      
      expect(Thor::Interactive::Shell).to have_received(:new).with(test_class, anything)
      expect(shell).to have_received(:start)
    end
  end
end