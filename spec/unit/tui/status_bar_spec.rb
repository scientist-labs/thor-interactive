# frozen_string_literal: true

require "spec_helper"
require "thor/interactive/tui/status_bar"

RSpec.describe Thor::Interactive::TUI::StatusBar do
  let(:thor_class) do
    Class.new(Thor) do
      def self.name
        "TestApp"
      end
    end
  end
  let(:thor_instance) { thor_class.new }

  describe "#initialize" do
    it "uses default sections" do
      bar = described_class.new(thor_class, thor_instance)
      text = bar.render_text(40)
      expect(text).to include("TestApp")
      expect(text).to include("ready")
    end

    it "accepts custom sections" do
      bar = described_class.new(thor_class, thor_instance, status_bar: {
        left: ->(i) { " custom" },
        right: ->(i) { " right " }
      })
      text = bar.render_text(40)
      expect(text).to include("custom")
      expect(text).to include("right")
    end

    it "accepts string sections" do
      bar = described_class.new(thor_class, thor_instance, status_bar: {
        left: " static",
        right: " info "
      })
      text = bar.render_text(30)
      expect(text).to include("static")
      expect(text).to include("info")
    end
  end

  describe "#render_text" do
    it "pads to fill width" do
      bar = described_class.new(thor_class, thor_instance)
      text = bar.render_text(50)
      expect(text.length).to eq(50)
    end

    it "supports override_right" do
      bar = described_class.new(thor_class, thor_instance)
      text = bar.render_text(50, override_right: " spinning... ")
      expect(text).to include("spinning...")
      expect(text).not_to include("ready")
    end

    it "supports override_center" do
      bar = described_class.new(thor_class, thor_instance)
      text = bar.render_text(50, override_center: "CENTER")
      expect(text).to include("CENTER")
    end

    it "handles lambdas with zero arity" do
      bar = described_class.new(thor_class, thor_instance, status_bar: {
        left: -> { " no args" }
      })
      text = bar.render_text(40)
      expect(text).to include("no args")
    end

    it "handles errors in sections gracefully" do
      bar = described_class.new(thor_class, thor_instance, status_bar: {
        left: ->(i) { raise "boom" }
      })
      text = bar.render_text(40)
      expect(text).to include("(error)")
    end
  end
end
