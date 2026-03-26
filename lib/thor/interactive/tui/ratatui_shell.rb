# frozen_string_literal: true

require "stringio"
require "io/console"
require "ratatui_ruby"
require_relative "../command_dispatch"
require_relative "output_buffer"
require_relative "text_input"
require_relative "status_bar"
require_relative "spinner"
require_relative "theme"

class Thor
  module Interactive
    module TUI
      class RatatuiShell
        DEFAULT_PROMPT = "> "
        DEFAULT_HISTORY_FILE = "~/.thor_interactive_history"

        # The viewport only contains: status bar (1) + input box (4)
        INPUT_VIEWPORT_HEIGHT = 5

        attr_reader :thor_class, :thor_instance, :prompt

        include CommandDispatch

        def initialize(thor_class, options = {})
          @thor_class = thor_class
          @thor_instance = thor_class.new

          merged_options = {}
          if thor_class.respond_to?(:interactive_options)
            merged_options.merge!(thor_class.interactive_options)
          end
          merged_options.merge!(options)

          @merged_options = merged_options
          @default_handler = merged_options[:default_handler]
          @prompt = merged_options[:prompt] || DEFAULT_PROMPT
          @history_file = File.expand_path(merged_options[:history_file] || DEFAULT_HISTORY_FILE)

          @text_input = TextInput.new
          @status_bar = StatusBar.new(thor_class, @thor_instance, merged_options)
          @spinner = Spinner.new(messages: merged_options[:spinner_messages])
          @theme = Theme.new(merged_options[:theme] || :default)
          @running = false
          @executing_command = false
          @completions = []
          @completion_index = -1

          # Ctrl-C handling
          @last_interrupt_time = nil
          @double_ctrl_c_timeout = merged_options.key?(:double_ctrl_c_timeout) ?
                                  merged_options[:double_ctrl_c_timeout] : 0.5

          load_history
        end

        def start
          was_in_session = ENV["THOR_INTERACTIVE_SESSION"]
          nesting_level = ENV["THOR_INTERACTIVE_LEVEL"].to_i

          ENV["THOR_INTERACTIVE_SESSION"] = "true"
          ENV["THOR_INTERACTIVE_LEVEL"] = (nesting_level + 1).to_s

          # Welcome message goes to normal stdout (above viewport = scrollable)
          puts "#{@thor_class.name} Interactive Shell (TUI mode)"
          puts "Enter to submit, Shift+Enter for newline, Ctrl+D to exit"
          puts

          @running = true

          RatatuiRuby.run(viewport: :inline, height: INPUT_VIEWPORT_HEIGHT, bracketed_paste: true) do |tui|
            @tui = tui
            disable_mouse_capture
            run_event_loop(tui)
          end

          save_history
          puts "Goodbye!"
        ensure
          @running = false
          if was_in_session
            ENV["THOR_INTERACTIVE_SESSION"] = "true"
            ENV["THOR_INTERACTIVE_LEVEL"] = nesting_level.to_s
          else
            ENV.delete("THOR_INTERACTIVE_SESSION")
            ENV.delete("THOR_INTERACTIVE_LEVEL")
          end
        end

        private

        def run_event_loop(tui)
          while @running
            render(tui)
            event = tui.poll_event(timeout: 0.05)
            handle_event(tui, event)
          end
        end

        def render(tui)
          tui.draw do |frame|
            area = frame.area
            # Layout: status bar (1) | input area (fill remaining)
            areas = RatatuiRuby::Layout::Layout.split(
              area,
              constraints: [
                RatatuiRuby::Layout::Constraint.length(1),
                RatatuiRuby::Layout::Constraint.fill(1)
              ],
              direction: :vertical
            )
            status_area, input_area = areas

            render_status_bar(frame, status_area)
            render_input(frame, input_area)
            render_completions(frame, input_area) unless @completions.empty?
          end
        end

        def render_status_bar(frame, area)
          width = area.to_ary[2]

          override_right = @spinner.active? ? @spinner.to_s : nil
          status_text = @status_bar.render_text(width, override_right: override_right)

          line = RatatuiRuby::Text::Line.new(
            spans: [RatatuiRuby::Text::Span.new(content: status_text, style: @theme.status_bar_style)]
          )

          paragraph = RatatuiRuby::Widgets::Paragraph.new(text: [line])
          frame.render_widget(paragraph, area)
        end

        def render_input(frame, area)
          input_lines = @text_input.lines
          cursor_row = @text_input.cursor_row
          cursor_col = @text_input.cursor_col

          text_lines = input_lines.each_with_index.map do |line, row|
            if row == cursor_row && @running && !@executing_command
              before = line[0...cursor_col] || ""
              cursor_char = line[cursor_col] || " "
              after = line[(cursor_col + 1)..] || ""

              spans = []
              spans << RatatuiRuby::Text::Span.new(content: before) unless before.empty?
              spans << RatatuiRuby::Text::Span.new(
                content: cursor_char,
                style: @theme.cursor_style
              )
              spans << RatatuiRuby::Text::Span.new(content: after) unless after.empty?

              RatatuiRuby::Text::Line.new(spans: spans)
            else
              RatatuiRuby::Text::Line.new(
                spans: [RatatuiRuby::Text::Span.new(content: line)]
              )
            end
          end

          block = RatatuiRuby::Widgets::Block.new(
            title: @prompt.strip,
            title_style: @theme.input_title_style,
            borders: [:all],
            border_style: @theme.input_border_style
          )

          paragraph = RatatuiRuby::Widgets::Paragraph.new(
            text: text_lines,
            block: block,
            wrap: true
          )

          frame.render_widget(paragraph, area)
        end

        def render_completions(frame, input_area)
          max_visible = [(@completions.length), 8].min
          height = max_visible + 2

          ia = input_area.to_ary
          comp_y = ia[1] - height
          comp_y = 0 if comp_y < 0

          comp_area = RatatuiRuby::Layout::Rect.new(ia[0] + 1, comp_y, [ia[2] - 2, 30].min, height)

          lines = @completions.first(max_visible).each_with_index.map do |comp, i|
            style = i == @completion_index ? @theme.completion_selected_style : @theme.completion_style
            RatatuiRuby::Text::Line.new(
              spans: [RatatuiRuby::Text::Span.new(content: " #{comp} ", style: style)]
            )
          end

          block = RatatuiRuby::Widgets::Block.new(
            title: "completions",
            borders: [:all],
            border_style: RatatuiRuby::Style::Style.new(fg: @theme[:completion_selected_bg]),
            style: @theme.completion_bg_style
          )

          paragraph = RatatuiRuby::Widgets::Paragraph.new(
            text: lines,
            block: block
          )

          frame.render_widget(paragraph, comp_area)
        end

        def handle_event(tui, event)
          case event
          when RatatuiRuby::Event::None
            # Timeout, nothing to do
          when RatatuiRuby::Event::Key
            handle_key_event(tui, event)
          when RatatuiRuby::Event::Paste
            handle_paste_event(event)
          when RatatuiRuby::Event::Resize
            # Will re-render on next loop
          end
        end

        def handle_key_event(tui, event)
          code = event.code
          modifiers = event.modifiers || []
          has_ctrl = modifiers.include?("ctrl")
          has_alt = modifiers.include?("alt")
          has_shift = modifiers.include?("shift")

          if !@completions.empty?
            handled = handle_completion_key(tui, code, has_ctrl, has_alt)
            return if handled
          end

          if has_ctrl
            case code
            when "d"
              if @text_input.empty?
                @running = false
              else
                @text_input.delete_char
              end
            when "c"
              handle_interrupt(tui)
            when "j", "enter"
              submit_input(tui)
            when "a"
              @text_input.move_home
            when "e"
              @text_input.move_end
            when "u"
              @text_input.clear
            end
          elsif has_shift && code == "enter"
            @text_input.newline
          elsif has_alt && code == "enter"
            @text_input.newline
          else
            case code
            when "enter"
              submit_input(tui)
            when "backspace"
              @text_input.backspace
              dismiss_completions
            when "delete"
              @text_input.delete_char
              dismiss_completions
            when "left"
              @text_input.move_left
              dismiss_completions
            when "right"
              @text_input.move_right
              dismiss_completions
            when "up"
              if @text_input.empty? || (@text_input.line_count == 1 && @text_input.cursor_row == 0)
                @text_input.history_back
              else
                @text_input.move_up
              end
            when "down"
              if @text_input.line_count == 1
                @text_input.history_forward
              else
                @text_input.move_down
              end
            when "home"
              @text_input.move_home
            when "end"
              @text_input.move_end
            when "tab"
              handle_tab_completion
            when "escape"
              if !@completions.empty?
                dismiss_completions
              else
                @text_input.clear
              end
            else
              if code.length == 1 && code.ord >= 32
                @text_input.insert_char(code)
                dismiss_completions
              end
            end
          end
        end

        def handle_completion_key(tui, code, has_ctrl, has_alt)
          case code
          when "tab"
            @completion_index = (@completion_index + 1) % @completions.length
            true
          when "enter"
            if @completion_index >= 0 && @completion_index < @completions.length
              accept_completion(@completions[@completion_index])
            end
            dismiss_completions
            true
          when "escape"
            dismiss_completions
            true
          else
            false
          end
        end

        def accept_completion(completion)
          line = @text_input.current_line
          col = @text_input.cursor_col
          before_cursor = line[0...col] || +""
          words = before_cursor.split(/\s+/, -1)
          current_word = words.last || +""

          current_word.length.times { @text_input.backspace }
          @text_input.insert_char(completion)
          @text_input.insert_char(" ")
        end

        def dismiss_completions
          @completions = []
          @completion_index = -1
        end

        def handle_paste_event(event)
          @text_input.insert_text(event.content) if event.respond_to?(:content)
        end

        def handle_interrupt(tui)
          current_time = Time.now

          if @last_interrupt_time && @double_ctrl_c_timeout &&
              (current_time - @last_interrupt_time) < @double_ctrl_c_timeout
            @running = false
            @last_interrupt_time = nil
            return
          end

          @last_interrupt_time = current_time
          @text_input.clear
          # Push interrupt message above viewport
          emit_above(tui, "^C (press Ctrl+C again to exit, Ctrl+D to exit)", style: :system)
        end

        def submit_input(tui)
          input = @text_input.submit
          return if input.strip.empty?

          # Echo the command above the viewport (into scrollback)
          emit_above(tui, "#{@prompt}#{input}", style: :command)

          if should_exit?(input)
            @running = false
            return
          end

          execute_with_capture(tui) do
            process_input(input.strip)
          end
        end

        def execute_with_capture(tui, &block)
          @executing_command = true
          @spinner.start

          captured_stdout = StringIO.new
          captured_stderr = StringIO.new

          # Run command in a thread so we can animate the spinner
          command_thread = Thread.new do
            old_stdout = $stdout
            old_stderr = $stderr
            $stdout = captured_stdout
            $stderr = captured_stderr

            begin
              block.call
            rescue SystemExit => e
              captured_stdout.puts "Command exited with code #{e.status}"
            rescue => e
              captured_stderr.puts "Error: #{e.message}"
            ensure
              $stdout = old_stdout
              $stderr = old_stderr
            end
          end

          # Animate spinner while waiting for command to finish
          while command_thread.alive?
            render(tui)
            event = tui.poll_event(timeout: 0.05)

            if event.is_a?(RatatuiRuby::Event::Key)
              code = event.code
              modifiers = event.modifiers || []
              if modifiers.include?("ctrl") && code == "c"
                command_thread.kill
                emit_above(tui, "^C Command interrupted", style: :error)
                break
              end
            end
          end

          command_thread.join(1)

          @spinner.stop
          @executing_command = false

          # Push all output above viewport into terminal scrollback
          stdout_text = captured_stdout.string
          stderr_text = captured_stderr.string

          unless stdout_text.strip.empty?
            emit_above(tui, strip_ansi(stdout_text).chomp)
          end

          unless stderr_text.strip.empty?
            emit_above(tui, strip_ansi(stderr_text).chomp, style: :error)
          end
        end

        # Push text above the inline viewport into terminal scrollback.
        # This is the key to the Claude Code-like UX: output lives in
        # normal terminal scrollback, not inside the TUI.
        def emit_above(tui, text, style: nil)
          lines = text.split("\n", -1).map do |line_text|
            ratatui_style = case style
            when :error then @theme.error_style
            when :command then @theme.command_echo_style
            when :system then @theme.system_style
            else nil
            end

            if ratatui_style
              RatatuiRuby::Text::Line.new(
                spans: [RatatuiRuby::Text::Span.new(content: line_text, style: ratatui_style)]
              )
            else
              RatatuiRuby::Text::Line.new(
                spans: [RatatuiRuby::Text::Span.new(content: line_text)]
              )
            end
          end

          paragraph = RatatuiRuby::Widgets::Paragraph.new(text: lines, wrap: true)
          tui.insert_before(lines.length, paragraph)
          render(tui)
        rescue => e
          # Silently ignore if insert_before fails
        end

        def handle_tab_completion
          input = @text_input.content
          return if input.empty?

          line = @text_input.current_line
          col = @text_input.cursor_col
          before_cursor = line[0...col] || +""

          words = before_cursor.split(/\s+/, -1)
          current_word = words.last || +""
          preposing = before_cursor[0...(before_cursor.length - current_word.length)]

          completions = complete_input(current_word, preposing)
          return if completions.empty?

          if completions.length == 1
            accept_completion(completions.first)
          else
            @completions = completions
            @completion_index = 0
          end
        end

        # Disable mouse capture so the terminal handles scrollback and
        # text selection natively. ratatui enables mouse capture by default
        # which intercepts mouse wheel (breaks scrollback) and click/drag
        # (breaks text selection). We don't use mouse events.
        def disable_mouse_capture
          tty = IO.console
          return unless tty

          # Disable all mouse tracking modes:
          #   ?1000 - normal tracking
          #   ?1002 - button-event tracking
          #   ?1003 - any-event tracking
          #   ?1006 - SGR extended mode
          tty.write("\e[?1000l\e[?1002l\e[?1003l\e[?1006l")
          tty.flush
        rescue
          # Not critical if this fails
        end

        def strip_ansi(text)
          text.gsub(/\e\[[0-9;]*[a-zA-Z]/, "")
        end

        def load_history
          return unless File.exist?(@history_file)

          entries = File.readlines(@history_file, chomp: true)
          @text_input.load_history(entries)
        rescue
          # Ignore history loading errors
        end

        def save_history
          entries = @text_input.history_entries
          return if entries.empty?

          File.write(@history_file, entries.join("\n"))
        rescue
          # Ignore history saving errors
        end
      end
    end
  end
end
