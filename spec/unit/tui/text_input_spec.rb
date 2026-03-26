# frozen_string_literal: true

require "spec_helper"
require "thor/interactive/tui/text_input"

RSpec.describe Thor::Interactive::TUI::TextInput do
  subject(:input) { described_class.new }

  describe "#insert_char" do
    it "inserts a character at cursor" do
      input.insert_char("a")
      input.insert_char("b")
      expect(input.content).to eq("ab")
      expect(input.cursor_col).to eq(2)
    end

    it "inserts at cursor position" do
      input.insert_char("a")
      input.insert_char("c")
      input.move_left
      input.insert_char("b")
      expect(input.content).to eq("abc")
    end
  end

  describe "#backspace" do
    it "removes character before cursor" do
      input.insert_char("a")
      input.insert_char("b")
      input.backspace
      expect(input.content).to eq("a")
      expect(input.cursor_col).to eq(1)
    end

    it "does nothing at start of first line" do
      input.backspace
      expect(input.content).to eq("")
    end

    it "joins with previous line when at start of line" do
      input.insert_char("a")
      input.newline
      input.insert_char("b")
      input.move_home
      input.backspace
      expect(input.content).to eq("ab")
      expect(input.cursor_row).to eq(0)
      expect(input.cursor_col).to eq(1)
    end
  end

  describe "#delete_char" do
    it "removes character at cursor" do
      input.insert_char("a")
      input.insert_char("b")
      input.move_left
      input.move_left
      input.delete_char
      expect(input.content).to eq("b")
    end

    it "joins with next line when at end of line" do
      input.insert_char("a")
      input.newline
      input.insert_char("b")
      input.move_up
      input.move_end
      input.delete_char
      expect(input.content).to eq("ab")
    end

    it "does nothing at end of last line" do
      input.insert_char("a")
      input.delete_char
      expect(input.content).to eq("a")
    end
  end

  describe "#newline" do
    it "splits current line at cursor" do
      input.insert_char("a")
      input.insert_char("b")
      input.move_left
      input.newline
      expect(input.line_count).to eq(2)
      expect(input.lines).to eq(["a", "b"])
      expect(input.cursor_row).to eq(1)
      expect(input.cursor_col).to eq(0)
    end

    it "creates empty line when at end" do
      input.insert_char("a")
      input.newline
      expect(input.lines).to eq(["a", ""])
    end
  end

  describe "cursor movement" do
    before do
      input.insert_char("ab")
      input.newline
      input.insert_char("cd")
    end

    it "#move_left wraps to previous line" do
      input.move_home
      input.move_left
      expect(input.cursor_row).to eq(0)
      expect(input.cursor_col).to eq(2)
    end

    it "#move_right wraps to next line" do
      input.move_up
      input.move_end
      input.move_right
      expect(input.cursor_row).to eq(1)
      expect(input.cursor_col).to eq(0)
    end

    it "#move_up clamps column to line length" do
      # Line 0 has "ab" (len 2), line 1 has "cd" (len 2)
      input.insert_char("ef") # line 1 is now "cdef"
      input.move_up
      expect(input.cursor_col).to eq(2) # clamped to "ab" length
    end

    it "#move_down clamps column to line length" do
      input.move_up
      input.move_end
      input.insert_char("gh") # line 0 is now "abgh"
      input.move_down
      expect(input.cursor_col).to eq(2) # clamped to "cd" length
    end

    it "#move_home goes to start of line" do
      input.move_home
      expect(input.cursor_col).to eq(0)
    end

    it "#move_end goes to end of line" do
      input.move_home
      input.move_end
      expect(input.cursor_col).to eq(2)
    end
  end

  describe "#insert_text" do
    it "inserts single-line text" do
      input.insert_text("hello")
      expect(input.content).to eq("hello")
    end

    it "inserts multi-line text" do
      input.insert_char("before")
      input.insert_text("\nmiddle\nafter")
      expect(input.line_count).to eq(3)
      expect(input.content).to eq("before\nmiddle\nafter")
    end

    it "handles paste into middle of existing text" do
      input.insert_char("ac")
      input.move_left
      input.insert_text("b")
      expect(input.content).to eq("abc")
    end
  end

  describe "#submit" do
    it "returns content and clears input" do
      input.insert_char("hello")
      result = input.submit
      expect(result).to eq("hello")
      expect(input).to be_empty
    end

    it "adds to history" do
      input.insert_char("cmd1")
      input.submit
      input.insert_char("cmd2")
      input.submit
      expect(input.history_entries).to eq(["cmd1", "cmd2"])
    end

    it "does not add empty commands to history" do
      input.submit
      expect(input.history_entries).to be_empty
    end

    it "does not add duplicate consecutive entries" do
      input.insert_char("cmd")
      input.submit
      input.insert_char("cmd")
      input.submit
      expect(input.history_entries).to eq(["cmd"])
    end
  end

  describe "history navigation" do
    before do
      input.insert_char("first")
      input.submit
      input.insert_char("second")
      input.submit
      input.insert_char("third")
      input.submit
    end

    it "navigates back through history" do
      input.history_back
      expect(input.content).to eq("third")
      input.history_back
      expect(input.content).to eq("second")
    end

    it "navigates forward through history" do
      input.history_back
      input.history_back
      input.history_forward
      expect(input.content).to eq("third")
    end

    it "restores saved input when going past end" do
      input.insert_char("current")
      input.history_back
      input.history_forward
      expect(input.content).to eq("current")
    end

    it "returns false when no more history" do
      expect(input.history_back).to be true
      expect(input.history_back).to be true
      expect(input.history_back).to be true
      expect(input.history_back).to be false
    end

    it "returns false when at end of history" do
      expect(input.history_forward).to be false
    end
  end

  describe "#load_history" do
    it "loads entries from array" do
      input.load_history(["cmd1", "cmd2"])
      input.history_back
      expect(input.content).to eq("cmd2")
    end
  end

  describe "#clear" do
    it "resets to empty state" do
      input.insert_char("data")
      input.newline
      input.insert_char("more")
      input.clear
      expect(input).to be_empty
      expect(input.cursor_row).to eq(0)
      expect(input.cursor_col).to eq(0)
      expect(input.line_count).to eq(1)
    end
  end

  describe "#empty?" do
    it "returns true for fresh input" do
      expect(input).to be_empty
    end

    it "returns false after character input" do
      input.insert_char("a")
      expect(input).not_to be_empty
    end

    it "returns false for empty newline (multi-line)" do
      input.newline
      expect(input).not_to be_empty
    end
  end
end
