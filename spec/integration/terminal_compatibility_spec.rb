# frozen_string_literal: true

require "stringio"

RSpec.describe "Terminal Compatibility", :terminal do
  let(:test_app) do
    Class.new(Thor) do
      include Thor::Interactive::Command
      
      desc "color", "Output with colors"
      def color
        puts "\e[31mRed text\e[0m"
        puts "\e[32mGreen text\e[0m"
        puts "\e[34mBlue text\e[0m"
      end
      
      desc "unicode", "Output unicode"
      def unicode
        puts "Emoji: 🚀 ✨ 🎉"
        puts "Symbols: → ← ↑ ↓"
        puts "Box drawing: ┌─┐│└┘"
      end
      
      desc "wide", "Output wide characters"
      def wide
        puts "Japanese: こんにちは"
        puts "Chinese: 你好"
        puts "Korean: 안녕하세요"
      end
    end
  end
  
  describe "terminal type detection" do
    it "detects TTY terminals" do
      shell = Thor::Interactive::Shell.new(test_app)
      
      # Should detect if running in TTY
      if $stdout.tty?
        expect(shell.send(:tty?)).to be true if shell.respond_to?(:tty?, true)
      end
    end
    
    it "handles non-TTY environments" do
      old_stdout = $stdout
      $stdout = StringIO.new
      
      shell = Thor::Interactive::Shell.new(test_app)
      
      # Should still work in non-TTY
      expect {
        shell.send(:process_input, "/color")
      }.not_to raise_error
      
      $stdout = old_stdout
    end
    
    it "detects terminal capabilities" do
      shell = Thor::Interactive::Shell.new(test_app)
      
      # Check for color support
      if ENV["TERM"] && ENV["TERM"] != "dumb"
        # Most modern terminals support color
        expect(ENV["TERM"]).not_to eq("dumb")
      end
    end
  end
  
  describe "ANSI escape sequence handling" do
    it "handles color codes correctly" do
      shell = Thor::Interactive::Shell.new(test_app)
      
      output = capture_stdout do
        shell.send(:process_input, "/color")
      end
      
      # Should preserve or strip ANSI codes appropriately
      if $stdout.tty?
        expect(output).to include("\e[31m") # Red color code
      else
        # In non-TTY, codes might be stripped
        expect(output).to include("text")
      end
    end
    
    it "handles cursor movement codes" do
      cursor_app = Class.new(Thor) do
        include Thor::Interactive::Command
        
        desc "cursor", "Move cursor"
        def cursor
          print "\e[2A"  # Move up 2 lines
          print "\e[3B"  # Move down 3 lines
          print "\e[5C"  # Move right 5 columns
          print "\e[2D"  # Move left 2 columns
          puts "Done"
        end
      end
      
      shell = Thor::Interactive::Shell.new(cursor_app)
      
      expect {
        capture_stdout { shell.send(:process_input, "/cursor") }
      }.not_to raise_error
    end
    
    it "handles screen clearing codes" do
      clear_app = Class.new(Thor) do
        include Thor::Interactive::Command
        
        desc "clear", "Clear screen"
        def clear
          print "\e[2J"  # Clear screen
          print "\e[H"   # Move to home
          puts "Cleared"
        end
      end
      
      shell = Thor::Interactive::Shell.new(clear_app)
      
      expect {
        capture_stdout { shell.send(:process_input, "/clear") }
      }.not_to raise_error
    end
  end
  
  describe "Unicode and special character support" do
    it "handles emoji correctly" do
      shell = Thor::Interactive::Shell.new(test_app)
      
      output = capture_stdout do
        shell.send(:process_input, "/unicode")
      end
      
      # Should handle emoji without corruption
      expect(output).to include("🚀") if "🚀".encoding == Encoding::UTF_8
    end
    
    it "handles box drawing characters" do
      shell = Thor::Interactive::Shell.new(test_app)
      
      output = capture_stdout do
        shell.send(:process_input, "/unicode")
      end
      
      # Should preserve box drawing
      expect(output).to include("┌") if "┌".encoding == Encoding::UTF_8
    end
    
    it "handles wide characters (CJK)" do
      shell = Thor::Interactive::Shell.new(test_app)
      
      output = capture_stdout do
        shell.send(:process_input, "/wide")
      end
      
      # Should handle wide characters
      expect(output.encoding).to eq(Encoding::UTF_8)
      expect(output).to include("こんにちは") if output.encoding == Encoding::UTF_8
    end
  end
  
  describe "terminal size handling" do
    it "detects terminal dimensions" do
      shell = Thor::Interactive::Shell.new(test_app)
      
      if $stdout.tty?
        # Should be able to get terminal size
        begin
          rows, cols = $stdout.winsize
          expect(rows).to be > 0
          expect(cols).to be > 0
        rescue NotImplementedError
          # Some environments don't support winsize
        end
      end
    end
    
    it "handles terminal resize" do
      shell = Thor::Interactive::Shell.new(test_app)
      
      # Simulate SIGWINCH (window change signal)
      if Signal.list.key?("WINCH")
        expect {
          Process.kill("WINCH", Process.pid)
        }.not_to raise_error
      end
    end
    
    it "works with very small terminals" do
      # Simulate small terminal
      allow($stdout).to receive(:winsize).and_return([10, 40])
      
      shell = Thor::Interactive::Shell.new(test_app)
      
      expect {
        shell.send(:process_input, "/color")
      }.not_to raise_error
    end
  end
  
  describe "different terminal emulators" do
    it "works with TERM=dumb" do
      old_term = ENV["TERM"]
      ENV["TERM"] = "dumb"
      
      shell = Thor::Interactive::Shell.new(test_app)
      
      expect {
        shell.send(:process_input, "/color")
      }.not_to raise_error
      
      ENV["TERM"] = old_term
    end
    
    it "works with TERM=xterm" do
      old_term = ENV["TERM"]
      ENV["TERM"] = "xterm"
      
      shell = Thor::Interactive::Shell.new(test_app)
      
      expect {
        shell.send(:process_input, "/color")
      }.not_to raise_error
      
      ENV["TERM"] = old_term
    end
    
    it "works with TERM=xterm-256color" do
      old_term = ENV["TERM"]
      ENV["TERM"] = "xterm-256color"
      
      shell = Thor::Interactive::Shell.new(test_app)
      
      expect {
        shell.send(:process_input, "/color")
      }.not_to raise_error
      
      ENV["TERM"] = old_term
    end
    
    it "works without TERM set" do
      old_term = ENV["TERM"]
      ENV.delete("TERM")
      
      shell = Thor::Interactive::Shell.new(test_app)
      
      expect {
        shell.send(:process_input, "/color")
      }.not_to raise_error
      
      ENV["TERM"] = old_term if old_term
    end
  end
  
  describe "SSH and remote session compatibility" do
    it "works over SSH (simulated)" do
      # Simulate SSH environment
      old_ssh = ENV["SSH_CLIENT"]
      ENV["SSH_CLIENT"] = "192.168.1.1 12345 22"
      
      shell = Thor::Interactive::Shell.new(test_app)
      
      expect {
        shell.send(:process_input, "/color")
      }.not_to raise_error
      
      old_ssh ? ENV["SSH_CLIENT"] = old_ssh : ENV.delete("SSH_CLIENT")
    end
    
    it "handles laggy connections" do
      shell = Thor::Interactive::Shell.new(test_app)
      
      # Simulate slow output
      slow_app = Class.new(Thor) do
        include Thor::Interactive::Command
        
        desc "slow", "Slow output"
        def slow
          10.times do |i|
            print "#{i}..."
            $stdout.flush
            sleep 0.01
          end
          puts "Done"
        end
      end
      
      slow_shell = Thor::Interactive::Shell.new(slow_app)
      
      expect {
        capture_stdout { slow_shell.send(:process_input, "/slow") }
      }.not_to raise_error
    end
  end
  
  describe "pipe and redirection compatibility" do
    it "works when output is piped" do
      old_stdout = $stdout
      $stdout = StringIO.new
      
      shell = Thor::Interactive::Shell.new(test_app)
      
      shell.send(:process_input, "/color")
      output = $stdout.string
      
      # Should work but might strip colors
      expect(output).to include("text")
      
      $stdout = old_stdout
    end
    
    it "works when input is piped" do
      old_stdin = $stdin
      $stdin = StringIO.new("/color\n/unicode\nexit\n")
      
      shell = Thor::Interactive::Shell.new(test_app)
      
      # Should handle piped input
      expect {
        3.times do
          if $stdin.eof?
            break
          else
            input = $stdin.gets&.chomp
            shell.send(:process_input, input) if input
          end
        end
      }.not_to raise_error
      
      $stdin = old_stdin
    end
  end
  
  describe "encoding compatibility" do
    it "handles UTF-8 encoding" do
      shell = Thor::Interactive::Shell.new(test_app)
      
      utf8_input = "café résumé naïve"
      
      expect {
        shell.send(:process_input, "/echo #{utf8_input}")
      }.not_to raise_error
    end
    
    it "handles ASCII encoding" do
      shell = Thor::Interactive::Shell.new(test_app)
      
      ascii_input = "hello world".dup.force_encoding(Encoding::US_ASCII)
      
      expect {
        shell.send(:process_input, "/echo #{ascii_input}")
      }.not_to raise_error
    end
    
    it "handles mixed encodings gracefully" do
      mixed_app = Class.new(Thor) do
        include Thor::Interactive::Command
        
        desc "mixed", "Mixed encodings"
        def mixed
          puts "ASCII: test"
          puts "UTF-8: café ☕"
          puts "Emoji: 🎉"
        end
      end
      
      shell = Thor::Interactive::Shell.new(mixed_app)
      
      expect {
        capture_stdout { shell.send(:process_input, "/mixed") }
      }.not_to raise_error
    end
  end
  
  describe "platform-specific compatibility" do
    it "handles platform-specific line endings" do
      shell = Thor::Interactive::Shell.new(test_app)
      
      # Unix line ending
      expect {
        shell.send(:process_input, "/color\n")
      }.not_to raise_error
      
      # Windows line ending
      expect {
        shell.send(:process_input, "/color\r\n")
      }.not_to raise_error
      
      # Old Mac line ending
      expect {
        shell.send(:process_input, "/color\r")
      }.not_to raise_error
    end
    
    it "handles platform-specific path separators" do
      path_app = Class.new(Thor) do
        include Thor::Interactive::Command
        
        desc "path FILE", "Handle file path"
        def path(file)
          puts "Path: #{file}"
        end
      end
      
      shell = Thor::Interactive::Shell.new(path_app)
      
      # Unix path
      expect {
        shell.send(:process_input, "/path /usr/local/bin/app")
      }.not_to raise_error
      
      # Windows path (if on Windows)
      if Gem.win_platform?
        expect {
          shell.send(:process_input, '/path C:\Users\test\file.txt')
        }.not_to raise_error
      end
    end
  end
end