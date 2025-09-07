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
    end
  end
end