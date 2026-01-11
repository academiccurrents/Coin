# frozen_string_literal: true

class CreateCoinPaymentOrders < ActiveRecord::Migration[6.0]
  def up
    unless table_exists?(:coin_payment_orders)
      create_table :coin_payment_orders do |t|
        t.integer :user_id, null: false
        t.integer :recharge_package_id
        t.string :out_trade_no, null: false
        t.string :trade_no
        t.integer :coin_amount, null: false
        t.decimal :original_price, precision: 10, scale: 2, null: false
        t.decimal :actual_price, precision: 10, scale: 2, null: false
        t.integer :discount_rate, null: false, default: 100
        t.string :payment_type, null: false
        t.integer :status, null: false, default: 0
        t.datetime :paid_at
        t.timestamps null: false
      end
    end

    unless index_exists?(:coin_payment_orders, :out_trade_no, name: "idx_coin_payment_orders_trade_no")
      add_index :coin_payment_orders, :out_trade_no, unique: true, name: "idx_coin_payment_orders_trade_no"
    end

    unless index_exists?(:coin_payment_orders, :user_id, name: "idx_coin_payment_orders_user_id")
      add_index :coin_payment_orders, :user_id, name: "idx_coin_payment_orders_user_id"
    end

    unless index_exists?(:coin_payment_orders, :status, name: "idx_coin_payment_orders_status")
      add_index :coin_payment_orders, :status, name: "idx_coin_payment_orders_status"
    end

    unless index_exists?(:coin_payment_orders, [:user_id, :created_at], name: "idx_coin_payment_orders_uid_created")
      add_index :coin_payment_orders, [:user_id, :created_at], name: "idx_coin_payment_orders_uid_created"
    end
  end

  def down
    drop_table :coin_payment_orders if table_exists?(:coin_payment_orders)
  end
end
