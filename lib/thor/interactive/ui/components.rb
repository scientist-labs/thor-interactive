# frozen_string_literal: true

class Thor
  module Interactive
    module UI
      module Components
        autoload :Spinner, "thor/interactive/ui/components/spinner"
        autoload :Progress, "thor/interactive/ui/components/progress"
        autoload :StatusBar, "thor/interactive/ui/components/status_bar"
        autoload :Menu, "thor/interactive/ui/components/menu"
      end
    end
  end
end