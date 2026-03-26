# frozen_string_literal: true

require "spec_helper"
require "thor/interactive/tui/output_buffer"

RSpec.describe Thor::Interactive::TUI::OutputBuffer do
  subject(:buffer) { described_class.new }

  describe "#append" do
    it "adds a line to the buffer" do
      buffer.append("hello")
      expect(buffer.line_count).to eq(1)
      expect(buffer.lines.first[:text]).to eq("hello")
    end

    it "splits multi-line text into separate entries" do
      buffer.append("line1\nline2\nline3")
      expect(buffer.line_count).to eq(3)
      expect(buffer.lines.map { |l| l[:text] }).to eq(%w[line1 line2 line3])
    end

    it "stores optional style" do
      buffer.append("error!", style: :error)
      expect(buffer.lines.first[:style]).to eq(:error)
    end

    it "preserves empty lines in multi-line text" do
      buffer.append("before\n\nafter")
      expect(buffer.line_count).to eq(3)
      expect(buffer.lines[1][:text]).to eq("")
    end

    it "converts non-string input to string" do
      buffer.append(42)
      expect(buffer.lines.first[:text]).to eq("42")
    end
  end

  describe "#empty?" do
    it "returns true when empty" do
      expect(buffer).to be_empty
    end

    it "returns false after append" do
      buffer.append("data")
      expect(buffer).not_to be_empty
    end
  end

  describe "#clear" do
    it "removes all lines" do
      buffer.append("data")
      buffer.clear
      expect(buffer).to be_empty
      expect(buffer.scroll_offset).to eq(0)
    end
  end

  describe "#visible_lines" do
    before do
      10.times { |i| buffer.append("line #{i}") }
    end

    it "returns last N lines when at bottom" do
      visible = buffer.visible_lines(3)
      expect(visible.map { |l| l[:text] }).to eq(["line 7", "line 8", "line 9"])
    end

    it "returns all lines when viewport is larger than content" do
      visible = buffer.visible_lines(20)
      expect(visible.length).to eq(10)
    end

    it "returns offset lines when scrolled up" do
      buffer.scroll_up(3)
      visible = buffer.visible_lines(3)
      expect(visible.map { |l| l[:text] }).to eq(["line 4", "line 5", "line 6"])
    end
  end

  describe "scrolling" do
    before do
      20.times { |i| buffer.append("line #{i}") }
    end

    it "starts at bottom" do
      expect(buffer).to be_at_bottom
    end

    it "scrolls up" do
      buffer.scroll_up(5)
      expect(buffer.scroll_offset).to eq(5)
      expect(buffer).not_to be_at_bottom
    end

    it "scrolls down" do
      buffer.scroll_up(10)
      buffer.scroll_down(3)
      expect(buffer.scroll_offset).to eq(7)
    end

    it "doesn't scroll below zero" do
      buffer.scroll_down(5)
      expect(buffer.scroll_offset).to eq(0)
    end

    it "doesn't scroll above max" do
      buffer.scroll_up(100)
      expect(buffer.scroll_offset).to eq(19) # max is line_count - 1
    end

    it "scrolls to bottom" do
      buffer.scroll_up(10)
      buffer.scroll_to_bottom
      expect(buffer).to be_at_bottom
    end

    it "scrolls to top" do
      buffer.scroll_to_top
      expect(buffer.scroll_offset).to eq(19)
    end

    it "auto-scrolls to bottom on new content" do
      buffer.scroll_up(5)
      buffer.append("new line")
      expect(buffer).to be_at_bottom
    end
  end

  describe "max_lines" do
    it "trims old lines when exceeding max" do
      small_buffer = described_class.new(max_lines: 5)
      10.times { |i| small_buffer.append("line #{i}") }
      expect(small_buffer.line_count).to eq(5)
      expect(small_buffer.lines.first[:text]).to eq("line 5")
    end
  end
end
