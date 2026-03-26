# frozen_string_literal: true

require "spec_helper"
require "thor/interactive/tui"

RSpec.describe Thor::Interactive::TUI do
  describe ".available?" do
    it "returns true when ratatui_ruby is installed" do
      expect(described_class.available?).to be true
    end
  end
end

RSpec.describe "TUI shell routing" do
  let(:test_app) do
    Class.new(Thor) do
      include Thor::Interactive::Command

      desc "greet NAME", "Say hello"
      def greet(name)
        puts "Hello, #{name}!"
      end
    end
  end

  describe "configure_interactive with ui_mode: :tui" do
    it "stores ui_mode in interactive_options" do
      test_app.configure_interactive(ui_mode: :tui)
      expect(test_app.interactive_options[:ui_mode]).to eq(:tui)
    end
  end
end

if Thor::Interactive::TUI.available?
  require "thor/interactive/tui/ratatui_shell"

  RSpec.describe Thor::Interactive::TUI::RatatuiShell do
    let(:thor_class) do
      Class.new(Thor) do
        desc "hello", "Say hello"
        def hello
          puts "Hello!"
        end

        desc "greet NAME", "Greet someone"
        def greet(name)
          puts "Hello, #{name}!"
        end

        desc "search QUERY", "Search for something"
        option :limit, type: :numeric, default: 10
        def search(query)
          puts "Searching for #{query} (limit: #{options[:limit]})"
        end
      end
    end

    let(:shell) { described_class.new(thor_class) }

    # Helper to set internal state
    def set_state(shell, **attrs)
      attrs.each { |k, v| shell.send(:instance_variable_set, :"@#{k}", v) }
    end

    describe "#initialize" do
      it "creates a shell with a Thor class" do
        expect(shell.thor_class).to eq(thor_class)
        expect(shell.thor_instance).to be_a(thor_class)
      end

      it "accepts custom prompt" do
        s = described_class.new(thor_class, prompt: "test> ")
        expect(s.prompt).to eq("test> ")
      end

      it "includes CommandDispatch" do
        expect(shell).to respond_to(:process_input)
        expect(shell).to respond_to(:complete_input)
        expect(shell).to respond_to(:show_help)
      end

      it "starts with multiline_mode and kitty_protocol off" do
        expect(shell.send(:instance_variable_get, :@multiline_mode)).to be false
        expect(shell.send(:instance_variable_get, :@kitty_protocol_active)).to be false
      end

      it "starts with no active completions" do
        expect(shell.send(:instance_variable_get, :@completions)).to eq([])
        expect(shell.send(:instance_variable_get, :@completion_index)).to eq(-1)
      end

      it "accepts custom spinner messages" do
        s = described_class.new(thor_class, spinner_messages: ["Working"])
        spinner = s.send(:instance_variable_get, :@spinner)
        expect(spinner.message).to eq("Working")
      end
    end

    describe "#input_title" do
      it "shows base prompt by default" do
        expect(shell.send(:input_title)).to eq(">")
      end

      it "shows [MULTI] indicator in fallback multiline mode" do
        set_state(shell, multiline_mode: true, kitty_protocol_active: false)
        title = shell.send(:input_title)
        expect(title).to include("[MULTI]")
        expect(title).to include("Ctrl+J to submit")
      end

      it "does not show [MULTI] when kitty protocol is active" do
        set_state(shell, kitty_protocol_active: true, multiline_mode: true)
        expect(shell.send(:input_title)).not_to include("[MULTI]")
      end

      it "shows submit hint when kitty protocol active and multiline content" do
        set_state(shell, kitty_protocol_active: true)
        text_input = shell.send(:instance_variable_get, :@text_input)
        text_input.insert_char("line1")
        text_input.newline
        text_input.insert_char("line2")
        expect(shell.send(:input_title)).to include("Enter to submit")
      end
    end

    describe "#handle_paste_event" do
      it "auto-enters multiline mode when paste contains newlines" do
        paste_event = double("PasteEvent", content: "line1\nline2")
        shell.send(:handle_paste_event, paste_event)
        expect(shell.send(:instance_variable_get, :@multiline_mode)).to be true
      end

      it "does not auto-enter multiline mode with kitty protocol" do
        set_state(shell, kitty_protocol_active: true)
        paste_event = double("PasteEvent", content: "line1\nline2")
        shell.send(:handle_paste_event, paste_event)
        expect(shell.send(:instance_variable_get, :@multiline_mode)).to be false
      end

      it "inserts the pasted text into the input" do
        paste_event = double("PasteEvent", content: "hello")
        shell.send(:handle_paste_event, paste_event)
        text_input = shell.send(:instance_variable_get, :@text_input)
        expect(text_input.content).to eq("hello")
      end

      it "does not crash when event has no content method" do
        event = double("BadEvent")
        expect { shell.send(:handle_paste_event, event) }.not_to raise_error
      end
    end

    describe "#handle_ctrl_key" do
      let(:tui) { double("tui") }

      it "Ctrl+D exits when input is empty" do
        shell.send(:handle_ctrl_key, tui, "d")
        expect(shell.send(:instance_variable_get, :@running)).to be false
      end

      it "Ctrl+D deletes char when input is not empty" do
        text_input = shell.send(:instance_variable_get, :@text_input)
        text_input.insert_char("ab")
        text_input.move_left
        shell.send(:handle_ctrl_key, tui, "d")
        expect(text_input.content).to eq("a")
      end

      it "Ctrl+N toggles multiline mode when kitty protocol inactive" do
        set_state(shell, kitty_protocol_active: false)
        shell.send(:handle_ctrl_key, tui, "n")
        expect(shell.send(:instance_variable_get, :@multiline_mode)).to be true
        shell.send(:handle_ctrl_key, tui, "n")
        expect(shell.send(:instance_variable_get, :@multiline_mode)).to be false
      end

      it "Ctrl+N does nothing when kitty protocol active" do
        set_state(shell, kitty_protocol_active: true)
        shell.send(:handle_ctrl_key, tui, "n")
        expect(shell.send(:instance_variable_get, :@multiline_mode)).to be false
      end

      it "Ctrl+A moves to start of line" do
        text_input = shell.send(:instance_variable_get, :@text_input)
        text_input.insert_char("hello")
        shell.send(:handle_ctrl_key, tui, "a")
        expect(text_input.cursor_col).to eq(0)
      end

      it "Ctrl+E moves to end of line" do
        text_input = shell.send(:instance_variable_get, :@text_input)
        text_input.insert_char("hello")
        text_input.move_home
        shell.send(:handle_ctrl_key, tui, "e")
        expect(text_input.cursor_col).to eq(5)
      end

      it "Ctrl+U clears input and exits multiline mode" do
        text_input = shell.send(:instance_variable_get, :@text_input)
        text_input.insert_char("text")
        set_state(shell, multiline_mode: true)
        shell.send(:handle_ctrl_key, tui, "u")
        expect(text_input.content).to eq("")
        expect(shell.send(:instance_variable_get, :@multiline_mode)).to be false
      end
    end

    describe "#handle_normal_key" do
      let(:tui) { double("tui") }

      it "Enter submits when not in multiline mode" do
        text_input = shell.send(:instance_variable_get, :@text_input)
        text_input.insert_char("/hello")
        set_state(shell, running: true)

        allow(shell).to receive(:emit_above)
        allow(shell).to receive(:execute_with_capture)

        shell.send(:handle_normal_key, tui, "enter")
        # Input should be cleared after submit
        expect(text_input.content).to eq("")
      end

      it "Enter inserts newline in multiline fallback mode" do
        text_input = shell.send(:instance_variable_get, :@text_input)
        text_input.insert_char("line1")
        set_state(shell, multiline_mode: true, kitty_protocol_active: false)
        shell.send(:handle_normal_key, tui, "enter")
        expect(text_input.line_count).to eq(2)
      end

      it "backspace dismisses completions" do
        text_input = shell.send(:instance_variable_get, :@text_input)
        text_input.insert_char("abc")
        set_state(shell, completions: ["/hello", "/help"], completion_index: 0)
        shell.send(:handle_normal_key, tui, "backspace")
        expect(shell.send(:instance_variable_get, :@completions)).to eq([])
      end

      it "backspace auto-exits multiline mode when input becomes empty" do
        text_input = shell.send(:instance_variable_get, :@text_input)
        text_input.insert_char("a")
        set_state(shell, multiline_mode: true)
        shell.send(:handle_normal_key, tui, "backspace")
        expect(shell.send(:instance_variable_get, :@multiline_mode)).to be false
      end

      it "up arrow navigates history when input is empty" do
        text_input = shell.send(:instance_variable_get, :@text_input)
        text_input.load_history(["cmd1", "cmd2"])
        shell.send(:handle_normal_key, tui, "up")
        expect(text_input.content).to eq("cmd2")
      end

      it "up arrow moves cursor when multi-line" do
        text_input = shell.send(:instance_variable_get, :@text_input)
        text_input.insert_char("line1")
        text_input.newline
        text_input.insert_char("line2")
        shell.send(:handle_normal_key, tui, "up")
        expect(text_input.cursor_row).to eq(0)
      end

      it "down arrow navigates history forward when single-line" do
        text_input = shell.send(:instance_variable_get, :@text_input)
        text_input.load_history(["cmd1", "cmd2"])
        text_input.history_back
        text_input.history_back
        shell.send(:handle_normal_key, tui, "down")
        expect(text_input.content).to eq("cmd2")
      end

      it "escape exits multiline mode and clears" do
        text_input = shell.send(:instance_variable_get, :@text_input)
        text_input.insert_char("text")
        set_state(shell, multiline_mode: true)
        shell.send(:handle_normal_key, tui, "escape")
        expect(shell.send(:instance_variable_get, :@multiline_mode)).to be false
        expect(text_input.content).to eq("")
      end

      it "escape dismisses completions first" do
        set_state(shell, completions: ["/hello"], completion_index: 0)
        shell.send(:handle_normal_key, tui, "escape")
        expect(shell.send(:instance_variable_get, :@completions)).to eq([])
      end

      it "inserts printable characters" do
        text_input = shell.send(:instance_variable_get, :@text_input)
        shell.send(:handle_normal_key, tui, "a")
        shell.send(:handle_normal_key, tui, "b")
        expect(text_input.content).to eq("ab")
      end

      it "ignores control characters" do
        text_input = shell.send(:instance_variable_get, :@text_input)
        shell.send(:handle_normal_key, tui, "\x01") # SOH
        expect(text_input.content).to eq("")
      end
    end

    describe "#handle_completion_key" do
      let(:tui) { double("tui") }

      before do
        set_state(shell, completions: ["/hello", "/help", "/history"], completion_index: 0)
      end

      it "tab cycles through completions" do
        shell.send(:handle_completion_key, tui, "tab", false, false)
        expect(shell.send(:instance_variable_get, :@completion_index)).to eq(1)
        shell.send(:handle_completion_key, tui, "tab", false, false)
        expect(shell.send(:instance_variable_get, :@completion_index)).to eq(2)
        shell.send(:handle_completion_key, tui, "tab", false, false)
        expect(shell.send(:instance_variable_get, :@completion_index)).to eq(0)
      end

      it "enter accepts selected completion and dismisses" do
        text_input = shell.send(:instance_variable_get, :@text_input)
        text_input.insert_char("/hel")
        set_state(shell, completions: ["/hello", "/help"], completion_index: 1)
        shell.send(:handle_completion_key, tui, "enter", false, false)
        expect(shell.send(:instance_variable_get, :@completions)).to eq([])
      end

      it "escape dismisses completions" do
        shell.send(:handle_completion_key, tui, "escape", false, false)
        expect(shell.send(:instance_variable_get, :@completions)).to eq([])
      end

      it "returns true for handled keys" do
        expect(shell.send(:handle_completion_key, tui, "tab", false, false)).to be true
        expect(shell.send(:handle_completion_key, tui, "escape", false, false)).to be true
      end

      it "returns false for unhandled keys" do
        expect(shell.send(:handle_completion_key, tui, "a", false, false)).to be false
      end
    end

    describe "#accept_completion" do
      it "replaces partial word with completion" do
        text_input = shell.send(:instance_variable_get, :@text_input)
        text_input.insert_char("/hel")
        shell.send(:accept_completion, "/hello")
        expect(text_input.content).to eq("/hello ")
      end

      it "handles completion at start of empty input" do
        shell.send(:accept_completion, "/hello")
        text_input = shell.send(:instance_variable_get, :@text_input)
        expect(text_input.content).to eq("/hello ")
      end
    end

    describe "#dismiss_completions" do
      it "clears completions and resets index" do
        set_state(shell, completions: ["/a", "/b"], completion_index: 1)
        shell.send(:dismiss_completions)
        expect(shell.send(:instance_variable_get, :@completions)).to eq([])
        expect(shell.send(:instance_variable_get, :@completion_index)).to eq(-1)
      end
    end

    describe "#handle_interrupt" do
      let(:tui) { double("tui") }

      before do
        set_state(shell, running: true)
        allow(shell).to receive(:emit_above)
      end

      it "clears input on single Ctrl+C" do
        text_input = shell.send(:instance_variable_get, :@text_input)
        text_input.insert_char("some text")
        shell.send(:handle_interrupt, tui)
        expect(text_input.content).to eq("")
      end

      it "exits multiline mode on Ctrl+C" do
        set_state(shell, multiline_mode: true)
        shell.send(:handle_interrupt, tui)
        expect(shell.send(:instance_variable_get, :@multiline_mode)).to be false
      end

      it "exits on double Ctrl+C within timeout" do
        shell.send(:handle_interrupt, tui)
        shell.send(:handle_interrupt, tui)
        expect(shell.send(:instance_variable_get, :@running)).to be false
      end

      it "does not exit on double Ctrl+C after timeout" do
        shell.send(:instance_variable_set, :@double_ctrl_c_timeout, 0.01)
        shell.send(:handle_interrupt, tui)
        sleep(0.02)
        shell.send(:handle_interrupt, tui)
        expect(shell.send(:instance_variable_get, :@running)).to be true
      end
    end

    describe "#handle_tab_completion" do
      it "does nothing when input is empty" do
        shell.send(:handle_tab_completion)
        expect(shell.send(:instance_variable_get, :@completions)).to eq([])
      end

      it "auto-accepts single completion" do
        text_input = shell.send(:instance_variable_get, :@text_input)
        text_input.insert_char("/hell")
        shell.send(:handle_tab_completion)
        # "hello" is the only match for "/hell"
        expect(text_input.content).to include("/hello")
      end

      it "shows multiple completions when ambiguous" do
        text_input = shell.send(:instance_variable_get, :@text_input)
        text_input.insert_char("/hel")
        shell.send(:handle_tab_completion)
        completions = shell.send(:instance_variable_get, :@completions)
        expect(completions.length).to be > 1
        expect(completions).to include("/hello")
        expect(completions).to include("/help")
      end
    end

    describe "#strip_ansi" do
      it "strips color codes" do
        expect(shell.send(:strip_ansi, "\e[31mred\e[0m")).to eq("red")
      end

      it "strips bold codes" do
        expect(shell.send(:strip_ansi, "\e[1mbold\e[0m")).to eq("bold")
      end

      it "handles text without ANSI codes" do
        expect(shell.send(:strip_ansi, "plain text")).to eq("plain text")
      end

      it "handles multiple codes" do
        expect(shell.send(:strip_ansi, "\e[31m\e[1mred bold\e[0m")).to eq("red bold")
      end
    end

    describe "command dispatch integration" do
      it "recognizes thor commands" do
        expect(shell.send(:thor_command?, "hello")).to be true
        expect(shell.send(:thor_command?, "greet")).to be true
        expect(shell.send(:thor_command?, "unknown")).to be false
      end

      it "completes commands" do
        completions = shell.send(:complete_commands, "he")
        expect(completions).to include("hello")
        expect(completions).to include("help")
      end

      it "completes with empty prefix" do
        completions = shell.send(:complete_commands, "")
        expect(completions).to include("hello")
        expect(completions).to include("greet")
      end
    end

    describe "multi-line without Kitty protocol (fallback workflow)" do
      let(:tui) { double("tui") }

      before do
        set_state(shell, kitty_protocol_active: false, running: true)
        allow(shell).to receive(:emit_above)
        allow(shell).to receive(:execute_with_capture)
      end

      it "Enter submits by default (single-line mode)" do
        text_input = shell.send(:instance_variable_get, :@text_input)
        text_input.insert_char("/hello")
        shell.send(:handle_normal_key, tui, "enter")
        expect(text_input.content).to eq("")
      end

      it "Ctrl+N enables multi-line mode" do
        shell.send(:handle_ctrl_key, tui, "n")
        expect(shell.send(:instance_variable_get, :@multiline_mode)).to be true
        expect(shell.send(:input_title)).to include("[MULTI]")
      end

      it "Enter inserts newline in multi-line mode" do
        text_input = shell.send(:instance_variable_get, :@text_input)
        shell.send(:handle_ctrl_key, tui, "n") # enable multiline
        text_input.insert_char("line1")
        shell.send(:handle_normal_key, tui, "enter")
        expect(text_input.line_count).to eq(2)
        expect(text_input.content).to eq("line1\n")
      end

      it "Ctrl+J submits in multi-line mode" do
        text_input = shell.send(:instance_variable_get, :@text_input)
        shell.send(:handle_ctrl_key, tui, "n") # enable multiline
        text_input.insert_char("line1")
        text_input.newline
        text_input.insert_char("line2")
        shell.send(:handle_ctrl_key, tui, "j")
        # submit clears input and resets multiline mode
        expect(text_input.content).to eq("")
        expect(shell.send(:instance_variable_get, :@multiline_mode)).to be false
      end

      it "Escape exits multi-line mode and clears input" do
        text_input = shell.send(:instance_variable_get, :@text_input)
        shell.send(:handle_ctrl_key, tui, "n")
        text_input.insert_char("draft")
        shell.send(:handle_normal_key, tui, "escape")
        expect(shell.send(:instance_variable_get, :@multiline_mode)).to be false
        expect(text_input.content).to eq("")
      end

      it "Ctrl+U clears and exits multi-line mode" do
        text_input = shell.send(:instance_variable_get, :@text_input)
        shell.send(:handle_ctrl_key, tui, "n")
        text_input.insert_char("text")
        shell.send(:handle_ctrl_key, tui, "u")
        expect(shell.send(:instance_variable_get, :@multiline_mode)).to be false
        expect(text_input.content).to eq("")
      end

      it "Ctrl+C clears and exits multi-line mode" do
        text_input = shell.send(:instance_variable_get, :@text_input)
        shell.send(:handle_ctrl_key, tui, "n")
        text_input.insert_char("text")
        shell.send(:handle_interrupt, tui)
        expect(shell.send(:instance_variable_get, :@multiline_mode)).to be false
        expect(text_input.content).to eq("")
      end

      it "pasting multi-line text auto-enters multi-line mode" do
        paste_event = double("PasteEvent", content: "line1\nline2\nline3")
        shell.send(:handle_paste_event, paste_event)
        expect(shell.send(:instance_variable_get, :@multiline_mode)).to be true
        text_input = shell.send(:instance_variable_get, :@text_input)
        expect(text_input.line_count).to eq(3)
      end

      it "pasting single-line text does not enter multi-line mode" do
        paste_event = double("PasteEvent", content: "just one line")
        shell.send(:handle_paste_event, paste_event)
        expect(shell.send(:instance_variable_get, :@multiline_mode)).to be false
      end

      it "backspace auto-exits multi-line mode when input becomes empty" do
        shell.send(:handle_ctrl_key, tui, "n")
        text_input = shell.send(:instance_variable_get, :@text_input)
        text_input.insert_char("x")
        shell.send(:handle_normal_key, tui, "backspace")
        expect(shell.send(:instance_variable_get, :@multiline_mode)).to be false
      end

      it "full workflow: toggle, type, submit, mode resets" do
        text_input = shell.send(:instance_variable_get, :@text_input)

        # Enable multi-line
        shell.send(:handle_ctrl_key, tui, "n")
        expect(shell.send(:input_title)).to include("[MULTI]")

        # Type multi-line content
        text_input.insert_char("SELECT *")
        shell.send(:handle_normal_key, tui, "enter")
        text_input.insert_char("FROM users")
        shell.send(:handle_normal_key, tui, "enter")
        text_input.insert_char("WHERE id = 1")
        expect(text_input.line_count).to eq(3)

        # Submit with Ctrl+J
        shell.send(:handle_ctrl_key, tui, "j")
        expect(text_input.content).to eq("")
        expect(shell.send(:instance_variable_get, :@multiline_mode)).to be false
        expect(shell.send(:input_title)).not_to include("[MULTI]")
      end
    end
  end
end
