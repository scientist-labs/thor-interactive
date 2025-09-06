# frozen_string_literal: true

require "thor/interactive"
require_relative "support/test_thor_apps"
require_relative "support/capture_helpers"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on Module and main
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Reset test app state between tests
  config.before(:each) do
    StatefulTestApp.class_variable_set(:@@counter, 0)
    StatefulTestApp.class_variable_set(:@@items, [])
  end

  # Mock readline by default to avoid terminal interaction
  config.before(:each) do
    allow(Reline::HISTORY).to receive(:<<)
    allow(Reline::HISTORY).to receive(:push)
    allow(Reline::HISTORY).to receive(:to_a).and_return([])
    allow(Reline::HISTORY).to receive(:size).and_return(0)
  end
end