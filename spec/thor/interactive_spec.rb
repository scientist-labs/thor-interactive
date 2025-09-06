# frozen_string_literal: true

RSpec.describe Thor::Interactive do
  it "has a version number" do
    expect(Thor::Interactive::VERSION).not_to be nil
  end

  describe ".start" do
    let(:test_thor_class) do
      Class.new(Thor) do
        desc "test", "A test command"
        def test
          puts "Test command executed"
        end
      end
    end

    it "creates and starts a shell" do
      shell = double("shell")
      expect(Thor::Interactive::Shell).to receive(:new)
        .with(test_thor_class, {})
        .and_return(shell)
      expect(shell).to receive(:start)

      Thor::Interactive.start(test_thor_class)
    end

    it "passes options to shell" do
      shell = double("shell")
      options = { prompt: "test> ", default_handler: proc {} }
      
      expect(Thor::Interactive::Shell).to receive(:new)
        .with(test_thor_class, options)
        .and_return(shell)
      expect(shell).to receive(:start)

      Thor::Interactive.start(test_thor_class, **options)
    end
  end
end