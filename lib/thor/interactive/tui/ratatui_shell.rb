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
        MIN_VIEWPORT_HEIGHT = 12
        VIEWPORT_MARGIN = 2 # lines reserved above viewport

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

          @output_buffer = OutputBuffer.new
          @text_input = TextInput.new
          @status_bar = StatusBar.new(thor_class, @thor_instance, merged_options)
          @spinner = Spinner.new
          @theme = Theme.new(merged_options[:theme] || :default)
          @running = false
          @executing_command = false
          @completions = []       # Active completion list
          @completion_index = -1  # Selected completion (-1 = none)

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

          @output_buffer.append("#{@thor_class.name} Interactive Shell (TUI mode)")
          @output_buffer.append("Enter to submit, Shift+Enter for newline, Ctrl+D to exit")
          @output_buffer.append("")

          @running = true

          viewport_height = compute_viewport_height
          RatatuiRuby.run(viewport: :inline, height: viewport_height, bracketed_paste: true) do |tui|
            @tui = tui
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

        def compute_viewport_height
          rows = nil
          if $stdout.respond_to?(:winsize)
            rows, _cols = $stdout.winsize rescue nil
          end
          rows ||= ENV["LINES"]&.to_i
          rows ||= `tput lines 2>/dev/null`.to_i rescue 0
          rows = 24 if rows < 1

          # Use most of the terminal, leave a small margin at top
          height = rows - VIEWPORT_MARGIN
          [height, MIN_VIEWPORT_HEIGHT].max
        end

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
            # Layout: output (fill) | status bar (1) | input (3)
            areas = RatatuiRuby::Layout::Layout.split(
              area,
              constraints: [
                RatatuiRuby::Layout::Constraint.fill(1),
                RatatuiRuby::Layout::Constraint.length(1),
                RatatuiRuby::Layout::Constraint.length(3)
              ],
              direction: :vertical
            )
            output_area, status_area, input_area = areas

            render_output(frame, output_area)
            render_status_bar(frame, status_area)
            render_input(frame, input_area)
            render_completions(frame, output_area) unless @completions.empty?
          end
        end

        def render_output(frame, area)
          visible = @output_buffer.visible_lines(area.to_ary[3])

          text_lines = visible.map do |entry|
            style = case entry[:style]
            when :error then @theme.error_style
            when :command then @theme.command_echo_style
            when :system then @theme.system_style
            else @theme.output_style
            end

            spans = [RatatuiRuby::Text::Span.new(content: entry[:text], style: style)]
            RatatuiRuby::Text::Line.new(spans: spans)
          end

          block = RatatuiRuby::Widgets::Block.new(
            borders: [:all],
            border_style: @theme.output_border_style
          )

          paragraph = RatatuiRuby::Widgets::Paragraph.new(
            text: text_lines,
            block: block,
            wrap: true
          )

          frame.render_widget(paragraph, area)
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
          # Build input text with cursor indicator
          input_lines = @text_input.lines
          cursor_row = @text_input.cursor_row
          cursor_col = @text_input.cursor_col

          text_lines = input_lines.each_with_index.map do |line, row|
            if row == cursor_row && @running && !@executing_command
              # Show cursor as inverted character
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

        def render_completions(frame, output_area)
          # Render completion overlay at bottom of output area
          max_visible = [(@completions.length), 8].min
          height = max_visible + 2 # +2 for borders

          # Position at the bottom of the output area
          oa = output_area.to_ary # [x, y, width, height]
          comp_y = oa[1] + oa[3] - height
          comp_y = oa[1] if comp_y < oa[1]

          comp_area = RatatuiRuby::Layout::Rect.new(oa[0] + 1, comp_y, [oa[2] - 2, 30].min, height)

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

          # If completions are showing, handle navigation first
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
              # Ctrl+J / Ctrl+Enter: always submit
              submit_input(tui)
            when "a"
              @text_input.move_home
            when "e"
              @text_input.move_end
            when "u"
              @text_input.clear
            end
          elsif has_shift && code == "enter"
            # Shift+Enter: always newline
            @text_input.newline
          elsif has_alt && code == "enter"
            # Alt+Enter: always newline
            @text_input.newline
          else
            case code
            when "enter"
              # Enter: always submit
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
            when "pageup"
              @output_buffer.scroll_up(5)
            when "pagedown"
              @output_buffer.scroll_down(5)
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
            # Cycle through completions
            @completion_index = (@completion_index + 1) % @completions.length
            true
          when "enter"
            # Accept selected completion
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
          # Remove the partial word and insert the completion
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
          @output_buffer.append("^C (press Ctrl+C again to exit, Ctrl+D to exit)", style: :system)
        end

        def submit_input(tui)
          input = @text_input.submit
          return if input.strip.empty?

          input_echo = "#{@prompt}#{input}"
          @output_buffer.append(input_echo, style: :command)

          if should_exit?(input)
            @running = false
            return
          end

          execute_with_capture(tui, input_echo) do
            process_input(input.strip)
          end
        end

        def execute_with_capture(tui, input_echo = "", &block)
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

          # Animate while waiting for command to finish
          while command_thread.alive?
            render(tui)
            event = tui.poll_event(timeout: 0.05)

            # Allow Ctrl+C to interrupt during execution
            if event.is_a?(RatatuiRuby::Event::Key)
              code = event.code
              modifiers = event.modifiers || []
              if modifiers.include?("ctrl") && code == "c"
                command_thread.kill
                @output_buffer.append("^C Command interrupted", style: :error)
                break
              end
            end
          end

          command_thread.join(1) # Wait briefly for cleanup

          @spinner.stop
          @executing_command = false

          # Collect all output lines
          stdout_text = captured_stdout.string
          stderr_text = captured_stderr.string

          output_lines = []
          unless stdout_text.empty?
            strip_ansi(stdout_text).split("\n", -1).each do |line|
              output_lines << {text: line, style: nil}
            end
          end
          unless stderr_text.empty?
            strip_ansi(stderr_text).split("\n", -1).each do |line|
              output_lines << {text: line, style: :error}
            end
          end

          # Show in the TUI output buffer
          output_lines.each { |l| @output_buffer.append(l[:text], style: l[:style]) }
          @output_buffer.append("")

          # Also push to terminal scrollback via insert_before
          # so the user can scroll up in the terminal after exiting
          push_to_scrollback(tui, input_echo, output_lines) unless output_lines.empty?
        end

        def push_to_scrollback(tui, command_echo, output_lines)
          # Build text lines for the scrollback block
          all_lines = []
          all_lines << RatatuiRuby::Text::Line.new(
            spans: [RatatuiRuby::Text::Span.new(
              content: command_echo,
              style: @theme.command_echo_style
            )]
          )
          output_lines.each do |entry|
            style = entry[:style] == :error ? @theme.error_style : @theme.output_style
            all_lines << RatatuiRuby::Text::Line.new(
              spans: [RatatuiRuby::Text::Span.new(content: entry[:text], style: style)]
            )
          end

          # Insert above the viewport
          height = all_lines.length
          tui.insert_before(height) do |frame|
            paragraph = RatatuiRuby::Widgets::Paragraph.new(
              text: all_lines,
              wrap: true
            )
            frame.render_widget(paragraph, frame.area)
          end
        rescue => e
          # insert_before may not be supported in all contexts
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
            # Show completions for cycling
            @completions = completions
            @completion_index = 0
          end
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
