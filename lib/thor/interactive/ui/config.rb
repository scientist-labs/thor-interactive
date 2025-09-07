# frozen_string_literal: true

class Thor
  module Interactive
    module UI
      class Config
        attr_accessor :enabled, :theme, :animations, :colors, :status_bar,
                      :input_mode, :suggestions, :fallback_mode
        
        def initialize
          @enabled = false
          @theme = :auto
          @animations = AnimationConfig.new
          @colors = ColorConfig.new
          @status_bar = StatusBarConfig.new
          @input_mode = :single_line
          @suggestions = SuggestionConfig.new
          @fallback_mode = :graceful
        end
        
        def enable!
          @enabled = true
          self
        end
        
        def disable!
          @enabled = false
          self
        end
        
        class AnimationConfig
          attr_accessor :enabled, :default_spinner, :speed
          
          def initialize
            @enabled = true
            @default_spinner = :dots
            @speed = :normal
          end
        end
        
        class ColorConfig
          attr_accessor :command, :natural_language, :suggestion, 
                        :warning, :error, :success
          
          def initialize
            @command = :blue
            @natural_language = :white
            @suggestion = :gray
            @warning = :yellow
            @error = :red
            @success = :green
          end
        end
        
        class StatusBarConfig
          attr_accessor :enabled, :position, :update_interval
          
          def initialize
            @enabled = false
            @position = :top
            @update_interval = 1.0
          end
        end
        
        class SuggestionConfig
          attr_accessor :enabled, :mode, :delay, :max_suggestions
          
          def initialize
            @enabled = false
            @mode = :inline
            @delay = 500
            @max_suggestions = 5
          end
        end
      end
    end
  end
end