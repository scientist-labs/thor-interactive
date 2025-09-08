# frozen_string_literal: true

class Thor
  module Interactive
    module UI
      module Components
        class AnimationEngine
          ANIMATION_STYLES = {
            spinner: {
              dots: ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"],
              dots2: ["⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷"],
              dots3: ["⠋", "⠙", "⠚", "⠞", "⠖", "⠦", "⠴", "⠲", "⠳", "⠓"],
              line: ["-", "\\", "|", "/"],
              line2: ["⠂", "-", "–", "—", "–", "-"],
              pipe: ["┤", "┘", "┴", "└", "├", "┌", "┬", "┐"],
              star: ["✶", "✸", "✹", "✺", "✹", "✸"],
              flip: ["_", "_", "_", "-", "`", "`", "'", "´", "-", "_", "_", "_"],
              bounce: ["⠁", "⠂", "⠄", "⠂"],
              box_bounce: ["▖", "▘", "▝", "▗"],
              triangle: ["◢", "◣", "◤", "◥"],
              arc: ["◜", "◠", "◝", "◞", "◡", "◟"],
              circle: ["◐", "◓", "◑", "◒"],
              square: ["◰", "◳", "◲", "◱"],
              arrow: ["←", "↖", "↑", "↗", "→", "↘", "↓", "↙"],
              arrow2: ["⬆️", "↗️", "➡️", "↘️", "⬇️", "↙️", "⬅️", "↖️"],
              clock: ["🕐", "🕑", "🕒", "🕓", "🕔", "🕕", "🕖", "🕗", "🕘", "🕙", "🕚", "🕛"]
            },
            progress: {
              bar: ["[          ]", "[=         ]", "[==        ]", "[===       ]", "[====      ]", 
                    "[=====     ]", "[======    ]", "[=======   ]", "[========  ]", "[========= ]", "[==========]"],
              dots: ["   ", ".  ", ".. ", "..."],
              blocks: ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"],
              wave: ["~", "≈", "≋", "≈", "~"],
              pulse: ["·", "•", "●", "•", "·"]
            },
            text: {
              typing: { pattern: ".", delay: 0.1 },
              reveal: { pattern: "█", delay: 0.05 },
              fade_in: { levels: [" ", "░", "▒", "▓", "█"], delay: 0.1 },
              fade_out: { levels: ["█", "▓", "▒", "░", " "], delay: 0.1 }
            }
          }
          
          attr_reader :active_animations
          
          def initialize
            @active_animations = {}
            @animation_threads = {}
            @mutex = Mutex.new
            @running = false
          end
          
          def start_animation(id, type: :spinner, style: :dots, options: {})
            @mutex.synchronize do
              stop_animation(id) if @active_animations[id]
              
              animation = {
                id: id,
                type: type,
                style: style,
                frame: 0,
                options: options,
                callback: options[:callback],
                position: options[:position] || { row: nil, col: nil }
              }
              
              @active_animations[id] = animation
              @animation_threads[id] = start_animation_thread(animation)
            end
          end
          
          def stop_animation(id)
            @mutex.synchronize do
              if thread = @animation_threads[id]
                thread.kill
                @animation_threads.delete(id)
              end
              @active_animations.delete(id)
            end
          end
          
          def stop_all
            @mutex.synchronize do
              @animation_threads.each { |_, thread| thread.kill }
              @animation_threads.clear
              @active_animations.clear
            end
          end
          
          def update_animation(id, options = {})
            @mutex.synchronize do
              if animation = @active_animations[id]
                animation[:options].merge!(options)
              end
            end
          end
          
          def with_animation(type: :spinner, style: :dots, message: nil, &block)
            id = "animation_#{Time.now.to_f}"
            
            start_animation(id, type: type, style: style, options: { message: message })
            
            begin
              result = yield
              stop_animation(id)
              result
            rescue => e
              stop_animation(id)
              raise e
            end
          end
          
          def text_animation(text, type: :typing, &block)
            case type
            when :typing
              animate_typing(text, &block)
            when :reveal
              animate_reveal(text, &block)
            when :fade_in
              animate_fade(text, :fade_in, &block)
            when :fade_out
              animate_fade(text, :fade_out, &block)
            else
              print text
            end
          end
          
          private
          
          def start_animation_thread(animation)
            Thread.new do
              frames = get_frames(animation[:type], animation[:style])
              interval = animation[:options][:interval] || 0.1
              
              while true
                frame = frames[animation[:frame] % frames.length]
                
                if animation[:callback]
                  animation[:callback].call(frame, animation[:frame])
                else
                  display_frame(animation, frame)
                end
                
                animation[:frame] += 1
                sleep interval
              end
            end
          end
          
          def get_frames(type, style)
            case type
            when :spinner
              ANIMATION_STYLES[:spinner][style] || ANIMATION_STYLES[:spinner][:dots]
            when :progress
              ANIMATION_STYLES[:progress][style] || ANIMATION_STYLES[:progress][:bar]
            else
              ["."]
            end
          end
          
          def display_frame(animation, frame)
            return unless tty?
            
            message = animation[:options][:message] || ""
            position = animation[:position]
            
            if position[:row] && position[:col]
              move_cursor(position[:row], position[:col])
            else
              print "\r"
            end
            
            clear_line
            
            if message.empty?
              print frame
            else
              print "#{frame} #{message}"
            end
            
            $stdout.flush
          end
          
          def animate_typing(text, &block)
            text.each_char do |char|
              print char
              $stdout.flush
              sleep(ANIMATION_STYLES[:text][:typing][:delay])
              yield(char) if block_given?
            end
            puts
          end
          
          def animate_reveal(text, &block)
            cursor = ANIMATION_STYLES[:text][:reveal][:pattern]
            delay = ANIMATION_STYLES[:text][:reveal][:delay]
            
            text.length.times do |i|
              print "\r#{text[0..i]}#{cursor}"
              $stdout.flush
              sleep(delay)
              yield(i) if block_given?
            end
            print "\r#{text} \n"
          end
          
          def animate_fade(text, direction, &block)
            levels = ANIMATION_STYLES[:text][direction][:levels]
            delay = ANIMATION_STYLES[:text][direction][:delay]
            
            levels.each_with_index do |level, i|
              print "\r#{text.gsub(/./, level)}"
              $stdout.flush
              sleep(delay)
              yield(level, i) if block_given?
            end
            
            if direction == :fade_in
              print "\r#{text}\n"
            else
              print "\r#{' ' * text.length}\r"
            end
          end
          
          def move_cursor(row, col)
            print "\e[#{row};#{col}H" if tty?
          end
          
          def clear_line
            print "\e[2K" if tty?
          end
          
          def tty?
            $stdout.tty? && !ENV['CI']
          end
        end
      end
    end
  end
end