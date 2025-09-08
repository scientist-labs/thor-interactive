#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "thor/interactive"

class AdvancedUIApp < Thor
  include Thor::Interactive::Command
  
  # Configure with advanced UI mode
  configure_interactive(
    ui_mode: :advanced,
    animations: true,
    status_bar: true,
    prompt: "ui-demo> ",
    default_handler: proc do |input, thor_instance|
      puts "Natural language: #{input}"
    end
  )
  
  desc "process FILES", "Process files with progress bar"
  def process(*files)
    if files.empty?
      puts "No files specified. Using example files..."
      files = %w[file1.txt file2.txt file3.txt file4.txt file5.txt]
    end
    
    with_progress(total: files.size, title: "Processing files") do |progress|
      files.each do |file|
        update_status("Processing: #{file}")
        
        # Simulate processing
        sleep 0.5
        
        puts "  ✓ Processed: #{file}"
        progress.advance if progress
      end
    end
    
    update_status("Complete!")
    puts "\nAll files processed successfully!"
  end
  
  desc "analyze TEXT", "Analyze text with spinner"
  def analyze(text = nil)
    text ||= "sample text for analysis"
    
    result = with_spinner("Analyzing '#{text}'...") do |spinner|
      # Simulate stages of analysis
      sleep 0.5
      spinner.update(title: "Tokenizing...") if spinner&.respond_to?(:update)
      sleep 0.5
      
      spinner.update(title: "Running NLP...") if spinner&.respond_to?(:update)
      sleep 0.5
      
      spinner.update(title: "Generating insights...") if spinner&.respond_to?(:update)
      sleep 0.5
      
      # Return analysis result
      {
        words: text.split.size,
        chars: text.length,
        sentiment: %w[positive neutral negative].sample
      }
    end
    
    puts "\nAnalysis Results:"
    puts "  Words: #{result[:words]}"
    puts "  Characters: #{result[:chars]}"
    puts "  Sentiment: #{result[:sentiment]}"
  end
  
  desc "download URL", "Download with progress animation"
  def download(url = "https://example.com/file.zip")
    puts "Downloading from: #{url}"
    
    with_spinner("Connecting...") do |spinner|
      sleep 0.5
      spinner.update(title: "Downloading...") if spinner&.respond_to?(:update)
      
      # Simulate download progress
      10.times do |i|
        spinner.update(title: "Downloading... #{(i + 1) * 10}%") if spinner&.respond_to?(:update)
        sleep 0.2
      end
    end
    
    puts "✓ Download complete!"
  end
  
  desc "menu", "Interactive menu demonstration"
  def menu
    if interactive_ui?
      choices = {
        "Process files" => -> { invoke :process },
        "Analyze text" => -> { invoke :analyze },
        "Download file" => -> { invoke :download },
        "Exit" => -> { puts "Goodbye!" }
      }
      
      # Try to use TTY::Prompt if available
      begin
        require 'tty-prompt'
        prompt = TTY::Prompt.new
        choice = prompt.select("Choose an action:", choices.keys)
        choices[choice].call
      rescue LoadError
        puts "Menu options:"
        choices.keys.each_with_index do |opt, i|
          puts "  #{i + 1}. #{opt}"
        end
        print "Choose (1-#{choices.size}): "
        choice_idx = gets.to_i - 1
        if choice_idx >= 0 && choice_idx < choices.size
          choices.values[choice_idx].call
        end
      end
    else
      puts "Interactive UI not enabled. Run in interactive mode for menu."
    end
  end
  
  desc "demo", "Run all UI demonstrations"
  def demo
    puts "=" * 50
    puts "Thor Interactive Advanced UI Demo"
    puts "=" * 50
    puts
    
    puts "1. Spinner Animation Demo:"
    puts "-" * 30
    invoke :analyze, ["Advanced UI features are working great!"]
    puts
    
    puts "2. Progress Bar Demo:"
    puts "-" * 30
    invoke :process, %w[doc1.pdf doc2.pdf doc3.pdf]
    puts
    
    puts "3. Download Animation Demo:"
    puts "-" * 30
    invoke :download
    puts
    
    puts "=" * 50
    puts "Demo complete!"
  end
end

if __FILE__ == $0
  # Start in interactive mode if no arguments
  if ARGV.empty?
    puts "Starting Advanced UI Demo in interactive mode..."
    puts "Try commands like: /demo, /analyze hello world, /process"
    puts
    AdvancedUIApp.start(["interactive"])
  else
    AdvancedUIApp.start(ARGV)
  end
end