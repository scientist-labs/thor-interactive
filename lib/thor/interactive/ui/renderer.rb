# frozen_string_literal: true

class Thor
  module Interactive
    module UI
      class Renderer
        attr_reader :config, :components
        
        def initialize(config = Config.new)
          @config = config
          @components = {}
          load_components if config.enabled
        end
        
        def with_spinner(message = nil, style: nil, &block)
          return yield unless spinner_available?
          
          spinner = create_spinner(message, style)
          spinner.auto_spin
          
          begin
            result = yield(spinner)
            spinner.success
            result
          rescue => e
            spinner.error
            raise e
          ensure
            spinner.stop
          end
        end
        
        def with_progress(total:, title: nil, &block)
          return yield(ProgressFallback.new) unless progress_available?
          
          progress = create_progress(total, title)
          
          begin
            yield(progress)
          ensure
            progress.finish
          end
        end
        
        def prompt(message, choices: nil, default: nil)
          return fallback_prompt(message, default) unless prompt_available?
          
          prompt = create_prompt
          
          if choices
            prompt.select(message, choices, default: default)
          else
            prompt.ask(message, default: default)
          end
        end
        
        def update_status(message)
          return unless @config.status_bar.enabled
          
          # Status bar implementation would go here
          puts "[STATUS] #{message}" if ENV['DEBUG']
        end
        
        def animate(type, message, &block)
          case type
          when :spinner
            with_spinner(message, &block)
          when :dots
            with_spinner(message, style: :dots, &block)
          when :progress
            # Progress requires total, so default to spinner
            with_spinner(message, &block)
          else
            yield if block_given?
          end
        end
        
        private
        
        def load_components
          load_tty_components
          load_color_components
        end
        
        def load_tty_components
          begin
            require 'tty-spinner' if FeatureDetection.animation_support?
            require 'tty-progressbar' if FeatureDetection.animation_support?
            require 'tty-prompt' if FeatureDetection.tty?
            require 'tty-cursor' if FeatureDetection.tty?
          rescue LoadError => e
            # Optional dependencies may not be available
            puts "UI component not available: #{e.message}" if ENV['DEBUG']
          end
        end
        
        def load_color_components
          begin
            require 'pastel' if FeatureDetection.color_support?
          rescue LoadError
            # Optional dependency
          end
        end
        
        def spinner_available?
          @config.animations.enabled && 
            FeatureDetection.animation_support? && 
            defined?(TTY::Spinner)
        end
        
        def progress_available?
          @config.animations.enabled && 
            FeatureDetection.animation_support? && 
            defined?(TTY::ProgressBar)
        end
        
        def prompt_available?
          FeatureDetection.tty? && defined?(TTY::Prompt)
        end
        
        def create_spinner(message, style)
          style ||= @config.animations.default_spinner
          format = spinner_format(style)
          TTY::Spinner.new(format, format: style)
        end
        
        def spinner_format(style)
          case style
          when :dots
            "[:spinner] #{style == :dots ? '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' : ''} :title"
          else
            "[:spinner] :title"
          end
        end
        
        def create_progress(total, title)
          TTY::ProgressBar.new(
            "#{title || 'Progress'} [:bar] :percent",
            total: total,
            bar_format: :block,
            width: [FeatureDetection.terminal_width - 20, 40].min
          )
        end
        
        def create_prompt
          TTY::Prompt.new
        end
        
        def fallback_prompt(message, default)
          print "#{message} "
          print "[#{default}] " if default
          input = $stdin.gets&.chomp
          input.empty? && default ? default : input
        end
        
        # Fallback for when progress bar is not available
        class ProgressFallback
          def initialize
            @current = 0
          end
          
          def advance(step = 1)
            @current += step
            print '.'
          end
          
          def finish
            puts
          end
        end
      end
    end
  end
end