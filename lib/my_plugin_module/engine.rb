# frozen_string_literal: true

module ::MyPluginModule
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace MyPluginModule
    
    # 确保加载路由
    config.paths["config/routes.rb"] = ["config/routes.rb"]
  end
end
