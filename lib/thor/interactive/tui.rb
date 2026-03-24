# frozen_string_literal: true

class Thor
  module Interactive
    module TUI
      def self.available?
        require "ratatui_ruby"
        true
      rescue LoadError
        false
      end
    end
  end
end
