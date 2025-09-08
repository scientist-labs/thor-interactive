#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "thor/interactive"
require_relative "../lib/thor/interactive/ui/components/paste_workaround"

class PasteDemo < Thor
  include Thor::Interactive::Command
  
  desc "paste", "Enter multi-line content via paste mode"
  def paste
    puts "\n=== Paste Mode Demo ==="
    puts "This works around Reline's paste limitations"
    
    result = Thor::Interactive::UI::Components::PasteWorkaround.read_paste_mode
    
    if result
      puts "\n--- Received: ---"
      puts result
      puts "--- End ---"
      puts "\nLines: #{result.lines.count}"
      puts "Bytes: #{result.bytesize}"
    else
      puts "\nCancelled"
    end
  end
  
  desc "editor", "Use external editor for multi-line input"
  def editor
    puts "\n=== External Editor Demo ==="
    puts "Opening #{ENV['EDITOR'] || 'default editor'}..."
    
    result = Thor::Interactive::UI::Components::PasteWorkaround.read_via_editor(
      "# Enter your multi-line content here\n# This method handles paste perfectly!\n\n"
    )
    
    if result && !result.empty?
      puts "\n--- Content from editor: ---"
      puts result
      puts "--- End ---"
    else
      puts "\nNo content entered"
    end
  end
  
  desc "clipboard", "Read from system clipboard"
  def clipboard
    puts "\n=== Clipboard Demo ==="
    puts "Checking clipboard contents..."
    
    result = Thor::Interactive::UI::Components::PasteWorkaround.read_from_clipboard
    
    if result
      puts "\n--- Using clipboard content: ---"
      puts result
      puts "--- End ---"
    else
      puts "\nNo clipboard content used"
    end
  end
  
  desc "file", "Load content from file"
  def file
    puts "\n=== File Load Demo ==="
    
    result = Thor::Interactive::UI::Components::PasteWorkaround.read_from_file
    
    if result
      puts "\n--- Loaded content: ---"
      puts result
      puts "--- End ---"
    else
      puts "\nNo file loaded"
    end
  end
  
  desc "heredoc", "Here-document style input"
  def heredoc
    puts "\n=== Here-document Style Demo ==="
    
    result = Thor::Interactive::UI::Components::PasteWorkaround.read_heredoc("DONE")
    
    if result && !result.empty?
      puts "\n--- Received: ---"
      puts result
      puts "--- End ---"
    else
      puts "\nNo content"
    end
  end
  
  desc "integrated", "Show integrated multi-line input menu"
  def integrated
    puts "\n=== Integrated Multi-line Input ==="
    
    result = Thor::Interactive::UI::Components::PasteWorkaround.read_multiline
    
    if result && !result.empty?
      puts "\n--- Final content: ---"
      puts result
      puts "--- End ---"
    else
      puts "\nNo content"
    end
  end
  
  desc "test_paste", "Test what happens when you paste"
  def test_paste
    puts "\n=== Paste Test ==="
    puts "Try pasting this multi-line content:"
    puts
    puts "def hello"
    puts "  puts 'world'"
    puts "  puts 'line 3'"
    puts "end"
    puts
    puts "Now paste it here (notice each line executes separately):"
    
    3.times do |i|
      input = Reline.readline("line #{i+1}> ", true)
      puts "Got: #{input.inspect}"
      break if input.nil?
    end
    
    puts "\nAs you can see, Reline treats each line as separate input!"
    puts "That's why we need workarounds."
  end
  
  desc "help_paste", "Explain paste limitations and solutions"
  def help_paste
    puts <<~HELP
    
    === Multi-line Paste in thor-interactive ===
    
    THE PROBLEM:
    Reline (Ruby's readline) cannot properly handle multi-line paste.
    When you paste multi-line content, each line is treated as pressing Enter.
    
    WORKAROUNDS WE PROVIDE:
    
    1. PASTE MODE (/paste)
       - Explicitly enter paste mode
       - Paste your content
       - Type 'END' to finish
       - Shows preview for large pastes
    
    2. EXTERNAL EDITOR (/edit)
       - Opens $EDITOR (vi, nano, etc.)
       - Paste works perfectly there
       - Save and exit to use content
    
    3. CLIPBOARD INTEGRATION (/clipboard)
       - Reads directly from system clipboard
       - Shows preview before using
       - Works on macOS and Linux
    
    4. FILE LOADING (/load <file>)
       - Load content from a file
       - Good for prepared content
    
    5. HERE-DOCUMENT STYLE
       - Type content line by line
       - End with delimiter (e.g., EOF)
    
    RECOMMENDED APPROACH:
    
    For small pastes (< 5 lines):
      Use paste mode or here-doc style
    
    For large pastes:
      Use external editor or clipboard
    
    For code/data:
      Save to file first, then load
    
    SHELL CONFIGURATION:
    
    You can add aliases to your shell:
      alias tpaste='thor interactive --paste-mode'
      alias tedit='thor interactive --editor'
    
    FUTURE IMPROVEMENTS:
    
    We're investigating:
    - Raw terminal mode for true paste detection
    - Integration with terminal multiplexers
    - Custom input handler in C/Rust
    
    HELP
  end
  
  default_task :help_paste
end

if __FILE__ == $0
  PasteDemo.start(ARGV)
end