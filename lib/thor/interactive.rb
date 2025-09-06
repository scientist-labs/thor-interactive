# frozen_string_literal: true

require_relative "interactive/version"
require_relative "interactive/shell"
require_relative "interactive/command"

class Thor
  module Interactive
    class Error < StandardError; end
    
    # Convenience method to start an interactive shell
    def self.start(thor_class, **options)
      Shell.new(thor_class, **options).start
    end
  end
end
