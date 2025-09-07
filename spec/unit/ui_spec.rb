# frozen_string_literal: true

require "spec_helper"

RSpec.describe Thor::Interactive::UI do
  before(:each) do
    described_class.reset!
  end
  
  describe ".configure" do
    it "yields config block" do
      described_class.configure do |config|
        config.enable!
        config.theme = :dark
      end
      
      expect(described_class.enabled?).to be true
      expect(described_class.config.theme).to eq(:dark)
    end
    
    it "defaults to disabled" do
      described_class.configure
      expect(described_class.enabled?).to be false
    end
  end
  
  describe ".enabled?" do
    it "returns false by default" do
      expect(described_class.enabled?).to be false
    end
    
    it "returns true when enabled" do
      described_class.configure(&:enable!)
      expect(described_class.enabled?).to be true
    end
  end
  
  describe ".renderer" do
    it "returns a renderer instance" do
      expect(described_class.renderer).to be_a(Thor::Interactive::UI::Renderer)
    end
    
    it "returns the same instance" do
      renderer1 = described_class.renderer
      renderer2 = described_class.renderer
      expect(renderer1).to be(renderer2)
    end
  end
end

RSpec.describe Thor::Interactive::UI::Config do
  describe "initialization" do
    subject { described_class.new }
    
    it "defaults to disabled" do
      expect(subject.enabled).to be false
    end
    
    it "has default theme :auto" do
      expect(subject.theme).to eq(:auto)
    end
    
    it "has animation config" do
      expect(subject.animations).to be_a(described_class::AnimationConfig)
      expect(subject.animations.enabled).to be true
    end
    
    it "has color config" do
      expect(subject.colors).to be_a(described_class::ColorConfig)
      expect(subject.colors.error).to eq(:red)
    end
  end
  
  describe "#enable!" do
    it "enables the config" do
      config = described_class.new
      config.enable!
      expect(config.enabled).to be true
    end
  end
end

RSpec.describe Thor::Interactive::UI::FeatureDetection do
  describe ".tty?" do
    it "detects TTY support" do
      allow($stdout).to receive(:tty?).and_return(true)
      allow($stdin).to receive(:tty?).and_return(true)
      expect(described_class.tty?).to be true
    end
    
    it "returns false for non-TTY" do
      allow($stdout).to receive(:tty?).and_return(false)
      expect(described_class.tty?).to be false
    end
  end
  
  describe ".color_support?" do
    it "returns false for NO_COLOR env" do
      ENV['NO_COLOR'] = '1'
      expect(described_class.color_support?).to be false
      ENV.delete('NO_COLOR')
    end
    
    it "returns true for FORCE_COLOR env" do
      ENV['FORCE_COLOR'] = '1'
      allow(described_class).to receive(:tty?).and_return(true)
      expect(described_class.color_support?).to be true
      ENV.delete('FORCE_COLOR')
    end
    
    it "returns false for dumb terminal" do
      ENV['TERM'] = 'dumb'
      allow(described_class).to receive(:tty?).and_return(true)
      expect(described_class.color_support?).to be false
    end
  end
  
  describe ".unicode_support?" do
    it "detects UTF-8 locale" do
      ENV['LANG'] = 'en_US.UTF-8'
      expect(described_class.unicode_support?).to be true
    end
    
    it "returns false for no LANG" do
      old_lang = ENV['LANG']
      ENV.delete('LANG')
      expect(described_class.unicode_support?).to be false
      ENV['LANG'] = old_lang if old_lang
    end
  end
  
  describe ".terminal_width" do
    it "gets terminal width from winsize" do
      allow(described_class).to receive(:tty?).and_return(true)
      allow($stdout).to receive(:winsize).and_return([24, 100])
      expect(described_class.terminal_width).to eq(100)
    end
    
    it "falls back to COLUMNS env" do
      allow(described_class).to receive(:tty?).and_return(false)
      ENV['COLUMNS'] = '120'
      expect(described_class.terminal_width).to eq(120)
    end
    
    it "defaults to 80" do
      allow(described_class).to receive(:tty?).and_return(false)
      ENV.delete('COLUMNS')
      expect(described_class.terminal_width).to eq(80)
    end
  end
end

RSpec.describe Thor::Interactive::UI::Renderer do
  let(:config) { Thor::Interactive::UI::Config.new }
  subject { described_class.new(config) }
  
  describe "#with_spinner" do
    context "when spinner not available" do
      before do
        allow(subject).to receive(:spinner_available?).and_return(false)
      end
      
      it "yields without spinner" do
        result = subject.with_spinner("Loading") { "done" }
        expect(result).to eq("done")
      end
    end
  end
  
  describe "#with_progress" do
    context "when progress not available" do
      before do
        allow(subject).to receive(:progress_available?).and_return(false)
      end
      
      it "yields with fallback" do
        result = subject.with_progress(total: 5) do |progress|
          expect(progress).to be_a(described_class::ProgressFallback)
          "complete"
        end
        expect(result).to eq("complete")
      end
    end
  end
  
  describe "#prompt" do
    context "when prompt not available" do
      before do
        allow(subject).to receive(:prompt_available?).and_return(false)
        allow($stdin).to receive(:gets).and_return("user input\n")
      end
      
      it "uses fallback prompt" do
        result = subject.prompt("Enter value:")
        expect(result).to eq("user input")
      end
      
      it "uses default when input is empty" do
        allow($stdin).to receive(:gets).and_return("\n")
        result = subject.prompt("Enter value:", default: "default")
        expect(result).to eq("default")
      end
    end
  end
end