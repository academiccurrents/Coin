# frozen_string_literal: true

class CreateCoinUserBalances < ActiveRecord::Migration[6.0]
  def up
    unless table_exists?(:coin_user_balances)
      create_table :coin_user_balances do |t|
        t.integer :user_id, null: false
        t.integer :balance, null: false, default: 0
        t.timestamps null: false
      end
    end

    unless index_exists?(:coin_user_balances, :user_id, name: "idx_coin_user_balances_user_id")
      add_index :coin_user_balances, :user_id, unique: true, name: "idx_coin_user_balances_user_id"
    end
  end

  def down
    drop_table :coin_user_balances if table_exists?(:coin_user_balances)
  end
end