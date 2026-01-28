#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "thor/interactive"

class CompletionDemo < Thor
  include Thor::Interactive::Command
  
  configure_interactive(
    prompt: "demo> "
  )
  
  desc "process FILE", "Process a file"
  option :output, type: :string, aliases: "-o", desc: "Output file"
  option :format, type: :string, enum: ["json", "xml", "yaml"], desc: "Output format"
  option :verbose, type: :boolean, aliases: "-v", desc: "Verbose output"
  def process(file)
    puts "Processing: #{file}"
    puts "Output to: #{options[:output]}" if options[:output]
    puts "Format: #{options[:format]}" if options[:format]
    puts "Verbose: ON" if options[:verbose]
  end
  
  desc "convert INPUT OUTPUT", "Convert file format"
  option :from, type: :string, required: true, desc: "Source format"
  option :to, type: :string, required: true, desc: "Target format"
  def convert(input, output)
    puts "Converting: #{input} -> #{output}"
    puts "Format: #{options[:from]} -> #{options[:to]}"
  end
  
  desc "read FILE", "Read a file"
  def read(file)
    if File.exist?(file)
      puts "Reading #{file}:"
      puts "-" * 40
      puts File.read(file).lines.first(10).join
      puts "-" * 40
      puts "(Showing first 10 lines)"
    else
      puts "File not found: #{file}"
    end
  end
  
  desc "list [DIR]", "List files in directory"
  option :all, type: :boolean, aliases: "-a", desc: "Show hidden files"
  option :long, type: :boolean, aliases: "-l", desc: "Long format"
  def list(dir = ".")
    puts "Listing files in: #{dir}"
    
    pattern = options[:all] ? "*" : "[^.]*"
    files = Dir.glob(File.join(dir, pattern))
    
    if options[:long]
      files.each do |file|
        stat = File.stat(file)
        type = File.directory?(file) ? "d" : "-"
        size = stat.size.to_s.rjust(10)
        name = File.basename(file)
        name += "/" if File.directory?(file)
        puts "#{type} #{size} #{name}"
      end
    else
      files.each { |f| puts File.basename(f) }
    end
  end
  
  desc "test", "Test completion features"
  def test
    puts <<~TEST
    
    === Path Completion Demo ===
    
    This demo showcases the new completion features:
    
    1. PATH COMPLETION
       Start typing a path and press TAB:
       /process <TAB>           # Shows files in current directory
       /process ex<TAB>         # Completes to 'examples/'
       /process ~/Doc<TAB>      # Completes home directory paths
       /process ./lib/<TAB>     # Shows files in lib directory
    
    2. OPTION COMPLETION
       Type - or -- and press TAB:
       /process file.txt --<TAB>     # Shows all options
       /process file.txt --v<TAB>    # Completes to --verbose
       /process file.txt -<TAB>      # Shows short options
    
    3. SMART DETECTION
       After file options, paths are completed:
       /process --output <TAB>       # Completes paths
       /process -o <TAB>             # Also completes paths
    
    4. COMMAND COMPLETION
       Still works as before:
       /proc<TAB>                    # Completes to /process
       /con<TAB>                     # Completes to /convert
    
    TRY THESE EXAMPLES:
    
    Basic file completion:
      /read <TAB>
      /read README<TAB>
      /read lib/<TAB>
      
    Option completion:
      /process file.txt --<TAB>
      /process file.txt --verb<TAB>
      /convert input.txt output.json --<TAB>
      
    Path after options:
      /process --output <TAB>
      /process -o ~/Desktop/<TAB>
      
    Directory listing:
      /list <TAB>
      /list examples/<TAB>
      /list --<TAB>
    
    TEST
  end
  
  desc "create_test_files", "Create test files for demo"
  def create_test_files
    puts "Creating test files..."
    
    # Create some test files
    files = [
      "test_file.txt",
      "test_data.json",
      "test_doc.md",
      "test_config.yaml",
      "test_log.log"
    ]
    
    files.each do |file|
      File.write(file, "Test content for #{file}\n")
      puts "  Created: #{file}"
    end
    
    # Create a test directory
    Dir.mkdir("test_dir") unless Dir.exist?("test_dir")
    File.write("test_dir/nested.txt", "Nested file content\n")
    puts "  Created: test_dir/nested.txt"
    
    puts "\nTest files created! Try tab completion with these files."
  end
  
  desc "clean_test_files", "Remove test files"
  def clean_test_files
    puts "Cleaning up test files..."
    
    files = [
      "test_file.txt",
      "test_data.json", 
      "test_doc.md",
      "test_config.yaml",
      "test_log.log",
      "test_dir/nested.txt"
    ]
    
    files.each do |file|
      if File.exist?(file)
        File.delete(file)
        puts "  Removed: #{file}"
      end
    end
    
    Dir.rmdir("test_dir") if Dir.exist?("test_dir") && Dir.empty?("test_dir")
    puts "Cleanup complete!"
  end
  
  default_task :test
end

if __FILE__ == $0
  puts "Path Completion Demo"
  puts "==================="
  puts
  puts "Tab completion now supports:"
  puts "  • File and directory paths"
  puts "  • Command option names"
  puts "  • Smart detection of when to complete paths"
  puts
  puts "Type '/test' for examples or '/create_test_files' to create test files"
  puts "Press TAB at any time to see completions!"
  puts
  
  CompletionDemo.new.interactive
end