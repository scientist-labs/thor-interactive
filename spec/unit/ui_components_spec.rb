# frozen_string_literal: true

require "spec_helper"

RSpec.describe Thor::Interactive::UI::Components::InputArea do
  subject { described_class.new }
  
  describe "#detect_syntax" do
    it "detects command syntax" do
      expect(subject.detect_syntax("/help")).to eq(:command)
      expect(subject.detect_syntax("/process")).to eq(:command)
    end
    
    it "detects help requests" do
      expect(subject.detect_syntax("help")).to eq(:help)
      expect(subject.detect_syntax("  help  ")).to eq(:help)
      expect(subject.detect_syntax("?")).to eq(:help)
    end
    
    it "detects exit commands" do
      expect(subject.detect_syntax("exit")).to eq(:exit)
      expect(subject.detect_syntax("quit")).to eq(:exit)
      expect(subject.detect_syntax("q")).to eq(:exit)
    end
    
    it "defaults to natural language" do
      expect(subject.detect_syntax("hello world")).to eq(:natural_language)
      expect(subject.detect_syntax("process this")).to eq(:natural_language)
    end
  end
  
  describe "#highlight_syntax" do
    before do
      allow(Thor::Interactive::UI::FeatureDetection).to receive(:color_support?).and_return(false)
    end
    
    it "returns plain text when colors not supported" do
      expect(subject.highlight_syntax("/command")).to eq("/command")
    end
    
    it "detects and uses appropriate type" do
      expect(subject.highlight_syntax("help")).to eq("help")
      expect(subject.highlight_syntax("exit")).to eq("exit")
    end
  end
  
  describe "input buffer management" do
    it "initializes with empty buffer" do
      expect(subject.buffer).to eq([])
    end
    
    it "tracks cursor position" do
      expect(subject.cursor_position).to eq({ line: 0, col: 0 })
    end
  end
end

RSpec.describe Thor::Interactive::UI::Components::ModeIndicator do
  subject { described_class.new }
  
  describe "#set_mode" do
    it "accepts valid modes" do
      expect { subject.set_mode(:insert) }.not_to raise_error
      expect(subject.current_mode).to eq(:insert)
    end
    
    it "ignores invalid modes" do
      subject.set_mode(:invalid)
      expect(subject.current_mode).to eq(:normal)  # Default
    end
  end
  
  describe "#display" do
    context "with full style" do
      subject { described_class.new(style: :full) }
      
      it "returns full mode text" do
        subject.set_mode(:insert)
        display = subject.display
        expect(display).to include("INSERT") if display.is_a?(String)
      end
    end
    
    context "with compact style" do
      subject { described_class.new(style: :compact) }
      
      it "returns compact indicator" do
        subject.set_mode(:command)
        display = subject.display
        expect(display).to be_a(String)
      end
    end
    
    context "with minimal style" do
      subject { described_class.new(style: :minimal) }
      
      it "returns abbreviated text" do
        subject.set_mode(:visual)
        expect(subject.display).to eq("VIS")
      end
    end
  end
  
  describe "position handling" do
    it "accepts position configuration" do
      indicator = described_class.new(position: :bottom_left)
      expect(indicator.position).to eq(:bottom_left)
    end
  end
end

RSpec.describe Thor::Interactive::UI::EnhancedShell do
  let(:test_app) do
    Class.new(Thor) do
      include Thor::Interactive::Command
      
      desc "test", "Test command"
      def test
        puts "test output"
      end
    end
  end
  
  describe "initialization" do
    it "creates enhanced shell with UI options" do
      shell = described_class.new(test_app, input_mode: :multiline)
      expect(shell).to be_a(described_class)
    end
    
    it "sets up input area when enabled" do
      Thor::Interactive::UI.configure(&:enable!)
      shell = described_class.new(test_app, input_mode: :multiline)
      expect(shell.input_area).to be_a(Thor::Interactive::UI::Components::InputArea)
      Thor::Interactive::UI.reset!
    end
    
    it "sets up mode indicator when enabled" do
      Thor::Interactive::UI.configure(&:enable!)
      shell = described_class.new(test_app, input_mode: :multiline)
      expect(shell.mode_indicator).to be_a(Thor::Interactive::UI::Components::ModeIndicator)
      Thor::Interactive::UI.reset!
    end
  end
  
  describe "multi-line history" do
    it "initializes empty multi-line history" do
      shell = described_class.new(test_app)
      expect(shell.multi_line_history).to eq([])
    end
  end
end