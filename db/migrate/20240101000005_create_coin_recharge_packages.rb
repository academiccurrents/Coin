# frozen_string_literal: true

class CreateCoinRechargePackages < ActiveRecord::Migration[6.0]
  def up
    unless table_exists?(:coin_recharge_packages)
      create_table :coin_recharge_packages do |t|
        t.integer :coin_amount, null: false
        t.decimal :price, precision: 10, scale: 2, null: false
        t.string :description
        t.integer :display_order, null: false, default: 0
        t.boolean :recommended, null: false, default: false
        t.boolean :active, null: false, default: true
        t.timestamps null: false
      end
    end

    unless index_exists?(:coin_recharge_packages, :active, name: "idx_coin_recharge_packages_active")
      add_index :coin_recharge_packages, :active, name: "idx_coin_recharge_packages_active"
    end

    unless index_exists?(:coin_recharge_packages, :display_order, name: "idx_coin_recharge_packages_order")
      add_index :coin_recharge_packages, :display_order, name: "idx_coin_recharge_packages_order"
    end
  end

  def down
    drop_table :coin_recharge_packages if table_exists?(:coin_recharge_packages)
  end
end
