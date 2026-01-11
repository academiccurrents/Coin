# frozen_string_literal: true

MyPluginModule::Engine.routes.draw do
  get "/" => "coin#index"
  get "/balance" => "coin#balance"
  get "/transactions" => "coin#transactions"
  post "/admin_adjust" => "coin#admin_adjust"
  
  get "/invoice" => "invoice#index"
  post "/invoice/create" => "invoice#create"
  post "/invoice/create_from_transaction" => "invoice#create_from_transaction"
  get "/invoice/list" => "invoice#list"
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
  post "/pay/notify" => "pay#notify_callback"
  get "/pay/return" => "pay#return_callback"
  get "/pay/order_status" => "pay#order_status"
  get "/pay/orders" => "pay#orders"
end
