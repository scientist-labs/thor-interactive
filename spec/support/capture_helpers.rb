# frozen_string_literal: true

# Helper methods for capturing output and simulating input during tests

module CaptureHelpers
  # Capture stdout output
  def capture_stdout(&block)
    old_stdout = $stdout
    $stdout = StringIO.new
    block.call
    $stdout.string
  ensure
    $stdout = old_stdout
  end

  # Capture stderr output
  def capture_stderr(&block)
    old_stderr = $stderr
    $stderr = StringIO.new
    block.call
    $stderr.string
  ensure
    $stderr = old_stderr
  end

  # Capture both stdout and stderr
  def capture_output(&block)
    {
      stdout: capture_stdout(&block),
      stderr: capture_stderr(&block)
    }
  end

  # Simulate input for readline
  def simulate_input(*inputs)
    inputs.each { |input| allow(Reline).to receive(:readline).and_return(input) }
  end

  # Mock readline to avoid actual terminal interaction
  def mock_readline
    allow(Reline).to receive(:readline).and_return("exit")
    allow(Reline).to receive(:completion_proc=)
    allow(Reline::HISTORY).to receive(:<<)
    allow(Reline::HISTORY).to receive(:push)
    allow(Reline::HISTORY).to receive(:to_a).and_return([])
    allow(Reline::HISTORY).to receive(:size).and_return(0)
  end

  # Create a temporary history file for testing
  def with_temp_history_file
    require 'tempfile'
    temp_file = Tempfile.new(['thor_interactive_test', '.history'])
    yield temp_file.path
  ensure
    temp_file&.unlink
  end

  # Stub file operations for history testing
  def stub_history_file(path, content = [])
    allow(File).to receive(:exist?).with(path).and_return(content.any?)
    allow(File).to receive(:readlines).with(path, chomp: true).and_return(content)
    allow(File).to receive(:write).with(path, anything)
  end
end

RSpec.configure do |config|
  config.include CaptureHelpers
end