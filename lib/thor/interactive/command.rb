# frozen_string_literal: true

require_relative "shell"

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
        end
      end
    end
  end
end