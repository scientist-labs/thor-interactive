#!/usr/bin/env ruby
# frozen_string_literal: true

# Demo script showing the difference between CLI and interactive modes

require_relative "../lib/thor/interactive"
require_relative "sample_app"

puts "=== Thor Interactive Demo ==="
puts
puts "1. CLI Mode (each command runs fresh):"
puts "   $ ruby sample_app.rb count"
puts "   $ ruby sample_app.rb count"
puts

system("ruby sample_app.rb count")
system("ruby sample_app.rb count")

puts "\n   Notice: Both show 'Count: 1' because state resets"
puts

puts "2. Interactive Mode (state persists):"
puts "   To see interactive mode, run:"
puts "   $ ruby sample_app.rb interactive"
puts
puts "   Then try these commands in sequence:"
puts "   sample> count"
puts "   sample> count" 
puts "   sample> add \"first item\""
puts "   sample> add \"second item\""
puts "   sample> list"
puts "   sample> status"
puts "   sample> help"
puts "   sample> This text goes to default handler"
puts "   sample> exit"
puts
puts "=== Key Differences ==="
puts
puts "CLI Mode:"
puts "- Fresh Thor instance each command"
puts "- No state persistence"
puts "- Standard Thor behavior"
puts
puts "Interactive Mode:"
puts "- Single persistent Thor instance"
puts "- State maintained between commands"
puts "- Auto-completion with TAB"
puts "- Command history with arrow keys"
puts "- Default handler for unrecognized input"
puts "- Built-in help system"
puts
puts "=== Features Implemented ==="
puts
puts "✓ Generic design - works with any Thor application"
puts "✓ State persistence through single Thor instance"
puts "✓ Auto-completion for command names"
puts "✓ Configurable default handlers"
puts "✓ Command history with persistent storage"
puts "✓ Both CLI and interactive modes supported"
puts "✓ Proper error handling and signal management"
puts "✓ Help system integration"
puts "✓ Comprehensive test suite"
puts
puts "Ready for your Claude Code-like RAG application!"