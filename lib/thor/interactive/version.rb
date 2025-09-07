# frozen_string_literal: true

require "thor"
require_relative "version_constant"

class Thor
  module Interactive
    VERSION = ThorInteractive::VERSION
  end
end
