# frozen_string_literal: true

class Thor
  module Interactive
    module UI
      # Main UI module for advanced terminal features
      autoload :Renderer, "thor/interactive/ui/renderer"
      autoload :Config, "thor/interactive/ui/config"
      autoload :Components, "thor/interactive/ui/components"
      autoload :FeatureDetection, "thor/interactive/ui/feature_detection"
      autoload :EnhancedShell, "thor/interactive/ui/enhanced_shell"
      
      class << self
        attr_accessor :config
        
        def configure
          @config ||= Config.new
          yield @config if block_given?
          @config
        end
        
        def enabled?
          @config&.enabled || false
        end
        
        def renderer
          @renderer ||= Renderer.new(@config || Config.new)
        end
        
        def reset!
          @renderer = nil
          @config = nil
        end
      end
    end
  end
end