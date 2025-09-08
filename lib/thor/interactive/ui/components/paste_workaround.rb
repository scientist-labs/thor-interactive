# frozen_string_literal: true

require 'tempfile'
require 'reline'

class Thor
  module Interactive
    module UI
      module Components
        # Practical workarounds for multi-line paste limitations
        class PasteWorkaround
          
          # Method 1: External editor
          def self.read_via_editor(initial_content = "")
            editor = ENV['EDITOR'] || ENV['VISUAL'] || 'vi'
            
            Tempfile.create(['input', '.txt']) do |f|
              f.write(initial_content)
              f.write("\n\n# Enter your content above. Lines starting with # are ignored.")
              f.flush
              
              # Open editor
              system("#{editor} #{f.path}")
              
              # Read back content
              content = File.read(f.path)
              
              # Remove comments and trailing whitespace
              content.lines
                     .reject { |line| line.strip.start_with?('#') }
                     .join
                     .rstrip
            end
          end
          
          # Method 2: Explicit paste mode
          def self.read_paste_mode
            puts "=== PASTE MODE ==="
            puts "Paste your content, then type 'END' on a new line:"
            puts
            
            lines = []
            loop do
              line = Reline.readline("paste> ", false)  # Don't add to history
              break if line.nil? || line.strip == 'END'
              lines << line
            end
            
            result = lines.join("\n")
            
            if lines.count > 10
              puts "\n[Pasted #{lines.count} lines - showing preview]"
              puts lines[0..2].map { |l| "  #{l.truncate(60)}" }
              puts "  ..."
              puts lines[-2..-1].map { |l| "  #{l.truncate(60)}" }
              
              print "\nAccept? (y/n): "
              response = $stdin.gets.chomp.downcase
              return nil unless response == 'y'
            end
            
            result
          end
          
          # Method 3: Load from file
          def self.read_from_file(prompt = "Enter filename: ")
            filename = Reline.readline(prompt, true)
            return nil if filename.nil? || filename.strip.empty?
            
            filename = File.expand_path(filename.strip)
            
            unless File.exist?(filename)
              puts "File not found: #{filename}"
              return nil
            end
            
            content = File.read(filename)
            lines = content.lines
            
            puts "\n[Loaded #{lines.count} lines from #{File.basename(filename)}]"
            
            if lines.count > 10
              puts "First 3 lines:"
              puts lines[0..2].map { |l| "  #{l.truncate(60)}" }
              puts "  ..."
            else
              puts content
            end
            
            content
          end
          
          # Method 4: Here-document style
          def self.read_heredoc(delimiter = "EOF")
            puts "Enter content (end with #{delimiter} on its own line):"
            
            lines = []
            loop do
              line = Reline.readline("| ", false)
              break if line.nil? || line.strip == delimiter
              lines << line
            end
            
            lines.join("\n")
          end
          
          # Method 5: Smart clipboard integration (macOS/Linux)
          def self.read_from_clipboard
            cmd = case RUBY_PLATFORM
                  when /darwin/
                    'pbpaste'
                  when /linux/
                    if system('which xclip > /dev/null 2>&1')
                      'xclip -selection clipboard -o'
                    elsif system('which xsel > /dev/null 2>&1')
                      'xsel --clipboard --output'
                    end
                  end
            
            unless cmd
              puts "Clipboard access not available on this platform"
              return nil
            end
            
            content = `#{cmd} 2>/dev/null`
            return nil if content.empty?
            
            lines = content.lines
            puts "\n[Clipboard contains #{lines.count} lines]"
            
            if lines.count > 10
              puts "First 3 lines:"
              puts lines[0..2].map { |l| "  #{l.truncate(60)}" }
              puts "  ..."
              puts "Last 2 lines:"
              puts lines[-2..-1].map { |l| "  #{l.truncate(60)}" }
            else
              puts content
            end
            
            print "\nUse clipboard content? (y/n): "
            response = $stdin.gets.chomp.downcase
            
            content if response == 'y'
          end
          
          # Integrated solution with multiple options
          def self.read_multiline(prompt = "> ")
            puts "\nMulti-line input options:"
            puts "  1. Type (with \\ for continuation)"
            puts "  2. Paste mode (type END to finish)"
            puts "  3. External editor"
            puts "  4. Load from file"
            puts "  5. From clipboard"
            puts "  6. Cancel"
            
            print "\nChoice [1]: "
            choice = $stdin.gets.chomp
            choice = "1" if choice.empty?
            
            case choice
            when "1"
              read_with_continuation(prompt)
            when "2"
              read_paste_mode
            when "3"
              read_via_editor
            when "4"
              read_from_file
            when "5"
              read_from_clipboard
            when "6"
              nil
            else
              puts "Invalid choice"
              nil
            end
          end
          
          private
          
          def self.read_with_continuation(prompt)
            lines = []
            current_prompt = prompt
            
            loop do
              line = Reline.readline(current_prompt, true)
              return lines.join("\n") if line.nil?
              
              if line.end_with?("\\")
                lines << line.chomp("\\")
                current_prompt = "... "
              else
                lines << line unless line.empty?
                break
              end
            end
            
            lines.join("\n")
          end
        end
        
        # String truncate helper
        class ::String
          def truncate(max_length)
            return self if length <= max_length
            "#{self[0...max_length-3]}..."
          end
        end
      end
    end
  end
end