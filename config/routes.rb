# frozen_string_literal: true

MyPluginModule::Engine.routes.draw do
  get "/" => "coin#index"
  get "/balance" => "coin#balance"
  get "/transactions" => "coin#transactions"
  post "/admin_adjust" => "coin#admin_adjust"
  
  get "/invoice" => "invoice#index"
  post "/invoice/create" => "invoice#create"
  post "/invoice/create_from_transaction" => "invoice#create_from_transaction"
  put "/invoice/update/:id" => "invoice#update"
  post "/invoice/resubmit/:id" => "invoice#resubmit"
  get "/invoice/list" => "invoice#list"
  get "/invoice/eligible_orders" => "invoice#eligible_orders"
  post "/invoice/update_status" => "invoice#update_status"
  
  get "/admin" => "admin#index"
  post "/admin/adjust_points" => "admin#adjust_points"
  get "/admin/user_balance" => "admin#get_user_balance"
  get "/admin/user_transactions" => "admin#get_user_transactions"
  get "/admin/recent_transactions" => "admin#recent_transactions"
  get "/admin/user_statistics" => "admin#user_statistics"
  get "/admin/pending_invoices" => "admin#pending_invoices"
  post "/admin/process_invoice" => "admin#process_invoice"
  get "/admin/completed_invoices" => "admin#completed_invoices"
  post "/admin/update_invoice_url" => "admin#update_invoice_url"

  # 充值支付相关路由
  get "/pay" => "pay#index"
  get "/pay/packages" => "pay#packages"
  get "/pay/channels" => "pay#payment_channels"
  post "/pay/create_order" => "pay#create_order"
  post "/pay/create_custom_order" => "pay#create_custom_order"
  
  # 易支付回调路由 - 使用 /callback 前缀避免与 Ember /pay 路由冲突
  get "/callback/notify" => "pay#notify_callback"
  post "/callback/notify" => "pay#notify_callback"
  get "/callback/return" => "pay#return_callback"
  
  get "/pay/order_status" => "pay#order_status"
  get "/pay/pending_order" => "pay#pending_order"
  get "/pay/orders" => "pay#orders"

  # 管理员套餐管理
  get "/pay/admin/packages" => "pay#admin_packages"
  post "/pay/admin/packages" => "pay#create_package"
  put "/pay/admin/packages/:id" => "pay#update_package"
  delete "/pay/admin/packages/:id" => "pay#delete_package"
  post "/pay/admin/seed_packages" => "pay#seed_packages"

  # 管理员渠道管理
  get "/pay/admin/channels" => "pay#admin_channels"
  put "/pay/admin/channels/:id" => "pay#update_channel"
  post "/pay/admin/seed_channels" => "pay#seed_channels"

  # 管理员折扣管理
  get "/pay/admin/discount_groups" => "pay#admin_discount_groups"
  post "/pay/admin/discount_groups" => "pay#create_discount_group"
  put "/pay/admin/discount_groups/:id" => "pay#update_discount_group"
  delete "/pay/admin/discount_groups/:id" => "pay#delete_discount_group"
  get "/pay/admin/discount_groups/:id/users" => "pay#discount_group_users"
  post "/pay/admin/discount_users" => "pay#add_discount_user"
  delete "/pay/admin/discount_users" => "pay#remove_discount_user"
  get "/pay/admin/search_users" => "pay#search_users"
end
