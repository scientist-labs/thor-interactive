# frozen_string_literal: true

require "spec_helper"
require "thor/interactive/tui"

if Thor::Interactive::TUI.available?
  require "thor/interactive/tui/theme"

  RSpec.describe Thor::Interactive::TUI::Theme do
    describe "#initialize" do
      it "defaults to the default theme" do
        theme = described_class.new
        expect(theme[:error_fg]).to eq(:red)
        expect(theme[:status_bar_bg]).to eq(:blue)
      end

      it "accepts a named theme" do
        theme = described_class.new(:dark)
        expect(theme[:status_bar_bg]).to eq(:dark_gray)
      end

      it "accepts a custom hash" do
        theme = described_class.new(error_fg: :magenta)
        expect(theme[:error_fg]).to eq(:magenta)
        # Falls back to defaults for unspecified keys
        expect(theme[:status_bar_bg]).to eq(:blue)
      end

      it "falls back to default for unknown theme name" do
        theme = described_class.new(:nonexistent)
        expect(theme[:error_fg]).to eq(:red)
      end
    end

    describe "predefined themes" do
      %i[default dark light minimal].each do |name|
        it "has a #{name} theme" do
          expect(described_class::THEMES).to have_key(name)
        end

        it "#{name} theme has all required keys" do
          theme = described_class.new(name)
          expected_keys = %i[
            output_fg output_border error_fg command_echo_fg system_fg
            input_fg input_border input_title_fg cursor_fg cursor_bg
            status_bar_fg status_bar_bg completion_fg completion_bg
            completion_selected_fg completion_selected_bg
          ]
          expected_keys.each do |key|
            expect(theme.colors).to have_key(key), "#{name} theme missing key: #{key}"
          end
        end
      end
    end

    describe "style methods" do
      let(:theme) { described_class.new }

      it "#error_style returns a Style" do
        expect(theme.error_style).to be_a(RatatuiRuby::Style::Style)
      end

      it "#cursor_style has fg and bg" do
        style = theme.cursor_style
        expect(style.fg).to eq(:black)
        expect(style.bg).to eq(:white)
      end

      it "#status_bar_style has fg and bg" do
        style = theme.status_bar_style
        expect(style.fg).to eq(:white)
        expect(style.bg).to eq(:blue)
      end

      it "#completion_selected_style has bold modifier" do
        style = theme.completion_selected_style
        expect(style.modifiers).to include(:bold)
      end

      it "#output_style returns nil when output_fg is nil" do
        expect(theme.output_style).to be_nil
      end

      it "#output_style returns Style when output_fg is set" do
        dark = described_class.new(:dark)
        expect(dark.output_style).to be_a(RatatuiRuby::Style::Style)
      end
    end
  end
end
