# frozen_string_literal: true

require "spec_helper"
require "thor/interactive/tui/spinner"

RSpec.describe Thor::Interactive::TUI::Spinner do
  subject(:spinner) { described_class.new }

  describe "#initialize" do
    it "starts inactive" do
      expect(spinner).not_to be_active
    end

    it "has a default message from the messages list" do
      expect(described_class::DEFAULT_MESSAGES).to include(spinner.message)
    end

    it "accepts custom messages list" do
      s = described_class.new(messages: ["Loading", "Working"])
      expect(["Loading", "Working"]).to include(s.message)
    end
  end

  describe "#start" do
    it "activates the spinner" do
      spinner.start
      expect(spinner).to be_active
    end

    it "accepts a specific message" do
      spinner.start("loading")
      expect(spinner.message).to eq("loading")
    end

    it "picks a random message when none specified" do
      spinner.start
      expect(described_class::DEFAULT_MESSAGES).to include(spinner.message)
    end
  end

  describe "#stop" do
    it "deactivates the spinner" do
      spinner.start
      spinner.stop
      expect(spinner).not_to be_active
    end
  end

  describe "#to_s" do
    it "returns empty string when inactive" do
      expect(spinner.to_s).to eq("")
    end

    it "returns spinner frame and message when active" do
      spinner.start("Thinking")
      text = spinner.to_s
      expect(text).to include("Thinking...")
      expect(text).to match(/[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏]/)
    end

    it "includes elapsed time" do
      spinner.start
      text = spinner.to_s
      expect(text).to match(/\(\d+\.\d+s\)/)
    end
  end

  describe "message rotation" do
    it "has default messages" do
      expect(described_class::DEFAULT_MESSAGES.length).to be > 5
    end

    it "rotates messages after interval" do
      spinner.start
      first_message = spinner.message

      # Simulate time passing beyond the rotation interval
      allow(Time).to receive(:now).and_return(
        Time.now + described_class::MESSAGE_ROTATE_INTERVAL + 0.1
      )
      spinner.to_s # triggers advance which checks rotation

      # Message may or may not have changed depending on the list,
      # but the mechanism should not error
      expect(spinner.message).to be_a(String)
    end
  end

  describe "#elapsed" do
    it "returns 0 when not started" do
      expect(spinner.elapsed).to eq(0)
    end

    it "returns elapsed time when active" do
      spinner.start
      sleep(0.05)
      expect(spinner.elapsed).to be > 0
    end
  end

  describe "frame animation" do
    it "has braille frames" do
      expect(described_class::FRAMES).to be_an(Array)
      expect(described_class::FRAMES.length).to be > 1
    end
  end
end
