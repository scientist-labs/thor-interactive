#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "thor/interactive"

class OptionsDemo < Thor
  include Thor::Interactive::Command
  
  configure_interactive(
    prompt: "opts> "
  )
  
  desc "process FILE", "Process a file with various options"
  option :verbose, type: :boolean, aliases: "-v", desc: "Enable verbose output"
  option :format, type: :string, default: "json", enum: ["json", "xml", "yaml", "csv"], desc: "Output format"
  option :output, type: :string, aliases: "-o", desc: "Output file"
  option :limit, type: :numeric, aliases: "-l", desc: "Limit number of results"
  option :skip, type: :numeric, default: 0, desc: "Skip N results"
  option :tags, type: :array, desc: "Tags to filter by"
  option :config, type: :hash, desc: "Additional configuration"
  option :dry_run, type: :boolean, desc: "Don't actually process, just show what would happen"
  def process(file)
    if options[:dry_run]
      puts "DRY RUN MODE - No actual processing"
    end
    
    puts "Processing file: #{file}"
    puts "=" * 50
    
    if options[:verbose]
      puts "Verbose mode enabled"
      puts "All options:"
      options.each do |key, value|
        puts "  #{key}: #{value.inspect}"
      end
      puts
    end
    
    puts "Format: #{options[:format]}"
    puts "Output: #{options[:output] || 'stdout'}"
    
    if options[:limit]
      puts "Limiting to #{options[:limit]} results"
      puts "Skipping first #{options[:skip]} results" if options[:skip] > 0
    end
    
    if options[:tags] && !options[:tags].empty?
      puts "Filtering by tags: #{options[:tags].join(', ')}"
    end
    
    if options[:config] && !options[:config].empty?
      puts "Configuration:"
      options[:config].each do |key, value|
        puts "  #{key}: #{value}"
      end
    end
    
    unless options[:dry_run]
      puts "\n[Simulating processing...]"
      sleep(1)
      puts "✓ Processing complete!"
    end
  end
  
  desc "search QUERY", "Search with options"
  option :case_sensitive, type: :boolean, aliases: "-c", desc: "Case sensitive search"
  option :regex, type: :boolean, aliases: "-r", desc: "Use regex"
  option :files, type: :array, aliases: "-f", desc: "Files to search in"
  option :max_results, type: :numeric, default: 10, desc: "Maximum results"
  def search(query)
    puts "Searching for: #{query}"
    puts "Options:"
    puts "  Case sensitive: #{options[:case_sensitive] ? 'Yes' : 'No'}"
    puts "  Regex mode: #{options[:regex] ? 'Yes' : 'No'}"
    puts "  Max results: #{options[:max_results]}"
    
    if options[:files]
      puts "  Searching in files: #{options[:files].join(', ')}"
    else
      puts "  Searching in all files"
    end
    
    # Simulate search
    results = [
      "result_1.txt:10: #{query} found here",
      "result_2.txt:25: another #{query} match",
      "result_3.txt:40: #{query} appears again"
    ]
    
    puts "\nResults:"
    results.take(options[:max_results]).each do |result|
      puts "  #{result}"
    end
  end
  
  desc "convert INPUT OUTPUT", "Convert file from one format to another"
  option :from, type: :string, required: true, desc: "Input format"
  option :to, type: :string, required: true, desc: "Output format"
  option :preserve_metadata, type: :boolean, desc: "Preserve file metadata"
  option :compression, type: :string, enum: ["none", "gzip", "bzip2", "xz"], default: "none"
  def convert(input, output)
    puts "Converting: #{input} → #{output}"
    puts "Format: #{options[:from]} → #{options[:to]}"
    puts "Compression: #{options[:compression]}"
    puts "Preserve metadata: #{options[:preserve_metadata] ? 'Yes' : 'No'}"
    
    # Validation
    unless File.exist?(input)
      puts "Error: Input file '#{input}' not found"
      return
    end
    
    puts "\n[Simulating conversion...]"
    puts "✓ Conversion complete!"
  end
  
  desc "test", "Test various option formats"
  def test
    puts "\n=== Option Parsing Test Cases ==="
    puts "\nTry these commands to test option parsing:\n"
    
    examples = [
      "/process file.txt --verbose",
      "/process file.txt -v",
      "/process data.json --format xml --output result.xml",
      "/process data.json --format=yaml --limit=100",
      "/process file.txt --tags important urgent todo",
      "/process file.txt --config env:production db:postgres",
      "/process file.txt -v --format csv -o output.csv --limit 50",
      "/process file.txt --dry-run --verbose",
      "",
      "/search 'hello world' --case-sensitive",
      "/search pattern -r -f file1.txt file2.txt file3.txt",
      "/search query --max-results 5",
      "",
      "/convert input.json output.yaml --from json --to yaml",
      "/convert data.csv data.json --from=csv --to=json --compression=gzip"
    ]
    
    examples.each do |example|
      puts example.empty? ? "" : "  #{example}"
    end
    
    puts "\n=== Features Demonstrated ==="
    puts "✓ Boolean options (--verbose, -v)"
    puts "✓ String options (--format xml, --format=xml)"
    puts "✓ Numeric options (--limit 100)"
    puts "✓ Array options (--tags tag1 tag2 tag3)"
    puts "✓ Hash options (--config key1:val1 key2:val2)"
    puts "✓ Required options (--from, --to in convert)"
    puts "✓ Default values (format: json, skip: 0)"
    puts "✓ Enum validation (format must be json/xml/yaml/csv)"
    puts "✓ Short aliases (-v for --verbose, -o for --output)"
    puts "✓ Multiple options in one command"
  end
  
  desc "help_options", "Explain how options work in interactive mode"
  def help_options
    puts <<~HELP
    
    === Option Parsing in thor-interactive ===
    
    Thor-interactive now fully supports Thor's option parsing!
    
    BASIC USAGE:
      /command arg1 arg2 --option value --flag
    
    OPTION TYPES:
      Boolean:  --verbose or -v (no value needed)
      String:   --format json or --format=json
      Numeric:  --limit 100 or --limit=100
      Array:    --tags tag1 tag2 tag3
      Hash:     --config key1:val1 key2:val2
    
    FEATURES:
      • Long form: --option-name value
      • Short form: -o value
      • Equals syntax: --option=value
      • Multiple options: --opt1 val1 --opt2 val2
      • Default values: Defined in Thor command
      • Required options: Must be provided
      • Enum validation: Limited to specific values
    
    BACKWARD COMPATIBILITY:
      • Commands without options work as before
      • Natural language still works for text commands
      • Single-text commands preserve their behavior
      • Default handler unaffected
    
    EXAMPLES:
      # Boolean flag
      /process file.txt --verbose
      
      # String option with equals
      /process file.txt --format=xml
      
      # Multiple options
      /process file.txt -v --format csv --limit 10
      
      # Array option
      /search term --files file1.txt file2.txt
      
      # Hash option  
      /deploy --config env:prod region:us-west
    
    HOW IT WORKS:
      1. Thor-interactive detects if command has options defined
      2. Uses Thor's option parser to parse the arguments
      3. Separates options from regular arguments
      4. Sets options hash on Thor instance
      5. Calls command with remaining arguments
      6. Falls back to original behavior if parsing fails
    
    NATURAL LANGUAGE:
      Natural language input still works! Options are only
      parsed for Thor commands that define them. Text sent
      to default handlers is unchanged.
    
    HELP
  end
  
  default_task :test
end

if __FILE__ == $0
  puts "Thor Options Demo"
  puts "=================="
  puts
  puts "This demo shows Thor option parsing in interactive mode."
  puts "Type '/test' to see examples or '/help_options' for details."
  puts
  
  OptionsDemo.new.interactive
end