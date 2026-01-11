# frozen_string_literal: true

class CreateCoinDiscountGroupUsers < ActiveRecord::Migration[6.0]
  def up
    unless table_exists?(:coin_discount_group_users)
      create_table :coin_discount_group_users do |t|
        t.integer :discount_group_id, null: false
        t.integer :user_id, null: false
        t.datetime :created_at, null: false
      end
    end

    unless index_exists?(:coin_discount_group_users, [:discount_group_id, :user_id], name: "idx_coin_dgu_group_user")
      add_index :coin_discount_group_users, [:discount_group_id, :user_id], unique: true, name: "idx_coin_dgu_group_user"
    end

    unless index_exists?(:coin_discount_group_users, :user_id, name: "idx_coin_dgu_user_id")
      add_index :coin_discount_group_users, :user_id, name: "idx_coin_dgu_user_id"
    end
  end

  def down
    drop_table :coin_discount_group_users if table_exists?(:coin_discount_group_users)
  end
end
