# frozen_string_literal: true

class AddPayUrlToCoinPaymentOrders < ActiveRecord::Migration[6.0]
  def up
    unless column_exists?(:coin_payment_orders, :pay_url)
      add_column :coin_payment_orders, :pay_url, :text
    end
  end

  def down
    remove_column :coin_payment_orders, :pay_url if column_exists?(:coin_payment_orders, :pay_url)
  end
end
