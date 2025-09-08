# frozen_string_literal: true

class Thor
  module Interactive
    module UI
      module Components
        autoload :Spinner, "thor/interactive/ui/components/spinner"
        autoload :Progress, "thor/interactive/ui/components/progress"
        autoload :StatusBar, "thor/interactive/ui/components/status_bar"
        autoload :Menu, "thor/interactive/ui/components/menu"
        autoload :InputArea, "thor/interactive/ui/components/input_area"
        autoload :ModeIndicator, "thor/interactive/ui/components/mode_indicator"
        autoload :AnimationEngine, "thor/interactive/ui/components/animation_engine"
        autoload :ProgressTracker, "thor/interactive/ui/components/progress_tracker"
      end
    end
  end
end