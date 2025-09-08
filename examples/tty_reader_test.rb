#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "tty-reader", "~> 0.9"
  gem "reline"
end

puts "=== Comparing Reline vs TTY::Reader ==="
puts

puts "RELINE FEATURES:"
puts "✓ Command history (up/down arrows)"
puts "✓ Tab completion (customizable)"
puts "✓ Line editing (left/right, home/end)"
puts "✓ Word navigation (Ctrl+left/right)"
puts "✓ History search (Ctrl+R)"
puts "✓ Persistent history file"
puts "✓ Works everywhere (SSH, pipes, etc.)"
puts "✗ No paste detection"
puts "✗ No multi-line handling"
puts

puts "TTY::READER FEATURES:"
require 'tty-reader'

reader = TTY::Reader.new

puts "Testing TTY::Reader capabilities..."
puts

# Test 1: Basic reading
puts "1. Basic input test:"
reader = TTY::Reader.new
reader.on(:keypress) do |event|
  puts "  [Detected: #{event.value.inspect}, key: #{event.key.name}]" if event.key
end

line = reader.read_line("tty> ", echo: true)
puts "  Got: #{line.inspect}"
puts

# Test 2: Multi-line capability
puts "2. Multi-line test (with custom handler):"
class MultilineReader
  def initialize
    @reader = TTY::Reader.new
    @buffer = []
    @in_paste = false
    @last_key_time = Time.now
  end
  
  def read_multiline(prompt = "> ")
    @buffer = [""]
    @line = 0
    @col = 0
    
    print prompt
    
    @reader.on(:keypress) do |event|
      current_time = Time.now
      time_diff = (current_time - @last_key_time) * 1000
      
      # Detect potential paste (keys arriving < 10ms apart)
      if time_diff < 10 && @buffer.join.length > 0
        @in_paste = true
      elsif time_diff > 100
        @in_paste = false
      end
      
      @last_key_time = current_time
      
      case event.key.name
      when :return
        if @in_paste
          # During paste, add newline to buffer
          @buffer << ""
          @line += 1
          @col = 0
          print "\n#{prompt}"
        else
          # Normal enter - check if we should continue
          if should_continue?
            @buffer << ""
            @line += 1
            @col = 0
            print "\n... "
          else
            # Submit
            return @buffer.join("\n")
          end
        end
      when :ctrl_d
        return @buffer.join("\n")
      when :escape
        return nil
      when :backspace
        if @col > 0
          @buffer[@line] = @buffer[@line][0...@col-1] + @buffer[@line][@col..-1]
          @col -= 1
          print "\b \b"
        end
      else
        if event.value
          @buffer[@line].insert(@col, event.value)
          @col += 1
          print event.value
        end
      end
    end
    
    @reader.read_keypress
  end
  
  private
  
  def should_continue?
    # Simple heuristic
    current_line = @buffer[@line]
    return true if current_line.end_with?("{", "[", "(")
    return true if current_line =~ /^\s*(def|class|if|while|do)\b/
    false
  end
end

ml = MultilineReader.new
puts "Type something (Ctrl+D to submit):"
# result = ml.read_multiline  # Would need event loop
puts "  [Multi-line reading would work but needs event loop]"
puts

# Test 3: Feature comparison
puts "3. What we'd need to recreate from Reline:"
features = {
  "History management" => "Need to implement ourselves",
  "Tab completion" => "Need custom implementation", 
  "History file" => "Need to save/load manually",
  "History search" => "Complex to recreate",
  "Line editing" => "Basic support, need to enhance",
  "Clipboard" => "Could add with system calls",
  "Multi-line paste" => "POSSIBLE with timing detection!"
}

features.each do |feature, status|
  puts "  #{feature}: #{status}"
end
puts

puts "4. Paste detection possibility:"
puts <<~CODE
  # With TTY::Reader we COULD detect paste:
  
  reader.on(:keypress) do |event|
    time_diff = (Time.now - @last_key_time) * 1000
    if time_diff < 10  # Less than 10ms between keys
      @paste_buffer << event.value
      @in_paste_mode = true
    elsif @in_paste_mode && time_diff > 50
      # Paste ended, process buffer
      handle_paste(@paste_buffer.join)
      @in_paste_mode = false
    end
  end
CODE

puts
puts "5. Implementation effort:"
puts "  ✓ Could detect paste (timing-based)"
puts "  ✓ Could handle multi-line properly"
puts "  ✗ Would lose history (need to reimplement)"
puts "  ✗ Would lose completion (need to reimplement)"
puts "  ✗ Would lose history search"
puts "  ✗ More complex codebase"
puts "  ~ May have issues over SSH/tmux"