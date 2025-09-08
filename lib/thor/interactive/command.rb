# frozen_string_literal: true

require_relative "shell"
require_relative "ui"

class Thor
  module Interactive
    # Mixin to add an interactive command to Thor applications
    module Command
      def self.included(base)
        base.extend(ClassMethods)
        base.class_eval do
          desc "interactive", "Start an interactive REPL for this application"
          option :prompt, type: :string, desc: "Custom prompt for the REPL"
          option :history_file, type: :string, desc: "Custom history file location"
          
          def interactive
            # Check for nested sessions unless explicitly allowed
            if ENV['THOR_INTERACTIVE_SESSION'] && !self.class.interactive_options[:allow_nested]
              puts "Already in an interactive session."
              puts "To allow nested sessions, configure with: configure_interactive(allow_nested: true)"
              return
            end
            
            opts = self.class.interactive_options.dup
            opts[:prompt] = options[:prompt] || options["prompt"] if options[:prompt] || options["prompt"]
            opts[:history_file] = options[:history_file] || options["history_file"] if options[:history_file] || options["history_file"]
            
            Thor::Interactive::Shell.new(self.class, opts).start
          end
        end
      end

      module ClassMethods
        def interactive_options
          @interactive_options ||= { allow_nested: false }
        end

        def configure_interactive(**options)
          interactive_options.merge!(options)
          
          # Configure UI if ui_mode is specified
          if options[:ui_mode]
            configure_ui(options)
          end
        end

        # Check if currently running in interactive mode
        def interactive?
          ENV['THOR_INTERACTIVE_SESSION'] == 'true'
        end
        
        # Check if advanced UI is available and enabled
        def interactive_ui?
          interactive? && UI.enabled?
        end
        
        private
        
        def configure_ui(options)
          UI.configure do |config|
            case options[:ui_mode]
            when :advanced
              config.enable!
              config.animations.enabled = options.fetch(:animations, true)
              config.status_bar.enabled = options.fetch(:status_bar, false)
              config.suggestions.enabled = options.fetch(:suggestions, false)
            when :basic
              config.disable!
            end
            
            config.theme = options[:theme] if options[:theme]
          end
        end
      end

      # Instance method version for use in commands
      def interactive?
        self.class.interactive?
      end
      
      # UI helper methods for Thor commands
      def with_spinner(message = nil, &block)
        if self.class.interactive_ui?
          UI.renderer.with_spinner(message, &block)
        else
          yield(nil)
        end
      end
      
      def with_progress(total:, title: nil, &block)
        if self.class.interactive_ui?
          UI.renderer.with_progress(total: total, title: title, &block)
        else
          yield(nil)
        end
      end
      
      def update_status(message)
        UI.renderer.update_status(message) if self.class.interactive_ui?
      end
      
      # New Phase 3 status API methods
      def status_bar
        @status_bar ||= UI::Components::StatusBar.new if self.class.interactive_ui?
      end
      
      def set_status(key, value, options = {})
        status_bar&.set(key, value, options)
      end
      
      def clear_status(key = nil)
        if key
          status_bar&.remove(key)
        else
          status_bar&.clear
        end
      end
      
      def with_status(message, &block)
        if status_bar
          set_status(:task, message, color: :cyan)
          begin
            result = yield
            set_status(:task, "✓ #{message}", color: :green)
            result
          rescue => e
            set_status(:task, "✗ #{message}", color: :red)
            raise e
          ensure
            sleep(0.5) # Brief pause to show final status
            clear_status(:task)
          end
        else
          yield
        end
      end
      
      # Animation API
      def animation_engine
        @animation_engine ||= UI::Components::AnimationEngine.new if self.class.interactive_ui?
      end
      
      def with_animation(type: :spinner, style: :dots, message: nil, &block)
        if animation_engine
          animation_engine.with_animation(type: type, style: style, message: message, &block)
        else
          yield
        end
      end
      
      def animate_text(text, type: :typing)
        if animation_engine
          animation_engine.text_animation(text, type: type)
        else
          puts text
        end
      end
      
      # Progress tracking API
      def progress_tracker
        @progress_tracker ||= UI::Components::ProgressTracker.new(
          status_bar: status_bar
        ) if self.class.interactive_ui?
      end
      
      def track_progress(name, total: 100, &block)
        if progress_tracker
          progress_tracker.with_task(name, total: total, &block)
        else
          yield
        end
      end
      
      def register_task(id, name, options = {})
        progress_tracker&.register_task(id, name, options)
      end
      
      def start_task(id)
        progress_tracker&.start_task(id)
      end
      
      def update_task_progress(id, progress, message = nil)
        progress_tracker&.update_progress(id, progress, message)
      end
      
      def complete_task(id, message = nil)
        progress_tracker&.complete_task(id, message)
      end
      
      def error_task(id, error_message)
        progress_tracker&.error_task(id, error_message)
      end
      
      def progress_summary
        progress_tracker&.summary || {}
      end
    end
  end
end