# frozen_string_literal: true

require 'io/console'
require 'timeout'

class Thor
  module Interactive
    module UI
      module Components
        class PasteHandler
          PASTE_THRESHOLD_MS = 10  # If chars arrive faster than this, it's likely paste
          LARGE_PASTE_LINES = 10   # Collapse if more than this many lines
          
          def self.read_with_paste_detection(prompt = "> ")
            return read_basic(prompt) unless $stdin.tty?
            
            print prompt
            $stdout.flush
            
            begin
              $stdin.raw!
              $stdin.echo = false
              
              buffer = ""
              paste_detected = false
              last_char_time = Time.now
              
              loop do
                char = read_char_with_timeout(0.001)  # 1ms timeout
                
                if char
                  # Check if this might be paste (chars arriving very fast)
                  current_time = Time.now
                  time_since_last = (current_time - last_char_time) * 1000  # ms
                  
                  if time_since_last < PASTE_THRESHOLD_MS && buffer.length > 0
                    paste_detected = true
                  end
                  
                  last_char_time = current_time
                  
                  # Handle special chars
                  case char
                  when "\r", "\n"
                    if paste_detected && buffer.include?("\n")
                      # Multi-line paste, keep reading
                      buffer += "\n"
                    else
                      # Normal enter or end of paste
                      break
                    end
                  when "\x03"  # Ctrl+C
                    raise Interrupt
                  when "\x04"  # Ctrl+D
                    break if buffer.empty?
                  when "\x7F", "\b"  # Backspace
                    if !paste_detected && buffer.length > 0
                      buffer.chop!
                      print "\b \b"
                      $stdout.flush
                    end
                  else
                    buffer += char
                    print char unless paste_detected
                    $stdout.flush
                  end
                else
                  # No more chars available
                  if paste_detected && buffer.length > 0
                    # End of paste
                    break
                  end
                end
              end
              
              handle_pasted_content(buffer, paste_detected)
              
            ensure
              $stdin.echo = true
              $stdin.cooked!
              puts
            end
          end
          
          private
          
          def self.read_char_with_timeout(timeout)
            Timeout.timeout(timeout) do
              $stdin.getc
            end
          rescue Timeout::Error
            nil
          end
          
          def self.handle_pasted_content(buffer, was_pasted)
            return buffer unless was_pasted
            
            lines = buffer.lines
            line_count = lines.count
            
            if line_count > LARGE_PASTE_LINES
              # Show collapsed view
              puts "\n[Pasted #{line_count} lines]"
              puts "First 3 lines:"
              puts lines[0..2].map { |l| "  #{l}" }
              puts "  ..."
              puts "Last 2 lines:"
              puts lines[-2..-1].map { |l| "  #{l}" }
              
              print "\nAccept paste? (y/n/e=edit): "
              response = $stdin.gets.chomp.downcase
              
              case response
              when 'y'
                buffer
              when 'e'
                edit_pasted_content(buffer)
              else
                nil
              end
            else
              # Show full paste for review
              puts "\n[Pasted #{line_count} lines:]"
              puts buffer
              puts "---"
              buffer
            end
          end
          
          def self.edit_pasted_content(content)
            # Could open in $EDITOR or provide inline editing
            require 'tempfile'
            
            Tempfile.open('paste_edit') do |f|
              f.write(content)
              f.flush
              
              editor = ENV['EDITOR'] || 'vi'
              system("#{editor} #{f.path}")
              
              File.read(f.path)
            end
          end
          
          def self.read_basic(prompt)
            # Fallback for non-TTY
            print prompt
            $stdin.gets
          end
        end
        
        # Alternative: Reline-based with paste buffer detection
        class RelinePasteHandler
          def self.setup_paste_detection
            # Track rapid input to detect paste
            @input_buffer = []
            @last_input_time = Time.now
            
            Reline.pre_input_hook = proc do
              @input_buffer.clear
              @paste_mode = false
            end
            
            # This is a conceptual example - Reline doesn't actually 
            # provide character-by-character hooks like this
            if defined?(Reline.input_hook)  # This doesn't exist but shows the idea
              Reline.input_hook = proc do |char|
                current_time = Time.now
                time_diff = (current_time - @last_input_time) * 1000
                
                if time_diff < 10  # Less than 10ms = probably paste
                  @paste_mode = true
                end
                
                @last_input_time = current_time
                @input_buffer << char
                
                if @paste_mode && char == "\n"
                  handle_paste(@input_buffer.join)
                end
              end
            end
          end
        end
      end
    end
  end
end