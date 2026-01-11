# frozen_string_literal: true

# name: coin
# about: 一款基于易支付的积分动态充值插件
# version: 0.0.2
# authors: pandacc
# url: https://github.com/werta666/coin
# required_version: 2.7.0

enabled_site_setting :coin_enabled

register_asset "stylesheets/coin.scss"

module ::MyPluginModule
  PLUGIN_NAME = "coin"
end

require_relative "lib/my_plugin_module/engine"

after_initialize do
  # 加载模型
  %w[
    coin_user_balance
    coin_transaction
    coin_invoice_request
    coin_recharge_package
    coin_discount_group
    coin_discount_group_user
    coin_payment_order
    coin_payment_channel
  ].each do |model|
    require_relative "app/models/my_plugin_module/#{model}"
  end

  # 加载服务
  %w[
    coin_service
    invoice_service
    discount_service
    epay_service
    payment_service
  ].each do |service|
    require_relative "lib/my_plugin_module/#{service}"
  end

  # 加载控制器
  %w[
    coin_controller
    admin_controller
    invoice_controller
    pay_controller
  ].each do |controller|
    require_relative "app/controllers/my_plugin_module/#{controller}"
  end

  # 挂载 Engine 到 /coin 路径
  Discourse::Application.routes.append do
    mount ::MyPluginModule::Engine, at: "/coin"
  end
  
  # 易支付回调路由 - 直接注册到 Discourse 主应用，绕过 Ember 路由
  Discourse::Application.routes.prepend do
    # 异步回调
    get "/coin_epay_notify" => "my_plugin_module/pay#notify_callback"
    post "/coin_epay_notify" => "my_plugin_module/pay#notify_callback"
    # 同步回调
    get "/coin_epay_return" => "my_plugin_module/pay#return_callback"
  end
end
