# frozen_string_literal: true

module ::MyPluginModule
  class Engine < ::Rails::Engine
    engine_name "discourse-coin"
    isolate_namespace MyPluginModule
  end
end
