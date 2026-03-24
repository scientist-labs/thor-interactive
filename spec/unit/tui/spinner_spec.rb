# frozen_string_literal: true

require "spec_helper"
require "thor/interactive/tui/spinner"

RSpec.describe Thor::Interactive::TUI::Spinner do
  subject(:spinner) { described_class.new }

  describe "#initialize" do
    it "starts inactive" do
      expect(spinner).not_to be_active
    end

    it "has default message" do
      expect(spinner.message).to eq("running")
    end

    it "accepts custom message" do
      s = described_class.new("processing")
      expect(s.message).to eq("processing")
    end
  end

  describe "#start" do
    it "activates the spinner" do
      spinner.start
      expect(spinner).to be_active
    end

    it "accepts a new message" do
      spinner.start("loading")
      expect(spinner.message).to eq("loading")
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
      spinner.start
      text = spinner.to_s
      expect(text).to include("running")
      # Should contain one of the braille spinner chars
      expect(text).to match(/[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏]/)
    end

    it "includes elapsed time" do
      spinner.start
      text = spinner.to_s
      expect(text).to match(/\(\d+\.\d+s\)/)
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
