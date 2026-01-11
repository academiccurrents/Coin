# frozen_string_literal: true

# name: discourse-coin
# about: 一款基于易支付的积分动态充值插件
# meta_topic_id: TODO
# version: 0.0.2
# authors: pandacc
# url: https://github.com/werta666/coin
# required_version: 2.7.0

enabled_site_setting :coin_enabled

register_asset "stylesheets/coin.scss"

module ::MyPluginModule
  PLUGIN_NAME = "discourse-coin"
end

require_relative "lib/my_plugin_module/engine"

after_initialize do
  Discourse::Application.routes.append do
    mount ::MyPluginModule::Engine, at: "/coin"
  end
end
