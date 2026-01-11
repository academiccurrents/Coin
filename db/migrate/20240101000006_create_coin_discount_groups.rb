# frozen_string_literal: true

class CreateCoinDiscountGroups < ActiveRecord::Migration[6.0]
  def up
    unless table_exists?(:coin_discount_groups)
      create_table :coin_discount_groups do |t|
        t.string :name, null: false
        t.integer :discount_rate, null: false, default: 100
        t.string :description
        t.timestamps null: false
      end
    end

    unless index_exists?(:coin_discount_groups, :name, name: "idx_coin_discount_groups_name")
      add_index :coin_discount_groups, :name, unique: true, name: "idx_coin_discount_groups_name"
    end
  end

  def down
    drop_table :coin_discount_groups if table_exists?(:coin_discount_groups)
  end
end
