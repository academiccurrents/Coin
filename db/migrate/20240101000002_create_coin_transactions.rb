# frozen_string_literal: true

class CreateCoinTransactions < ActiveRecord::Migration[6.0]
  def up
    unless table_exists?(:coin_transactions)
      create_table :coin_transactions do |t|
        t.integer :user_id, null: false
        t.integer :amount, null: false
        t.integer :balance_after, null: false
        t.string :reason, null: false
        t.string :transaction_type, null: false
        t.timestamps null: false
      end
    end

    unless index_exists?(:coin_transactions, :user_id, name: "idx_coin_transactions_user_id")
      add_index :coin_transactions, :user_id, name: "idx_coin_transactions_user_id"
    end

    unless index_exists?(:coin_transactions, [:user_id, :created_at], name: "idx_coin_transactions_uid_created")
      add_index :coin_transactions, [:user_id, :created_at], name: "idx_coin_transactions_uid_created"
    end

    unless index_exists?(:coin_transactions, :transaction_type, name: "idx_coin_transactions_type")
      add_index :coin_transactions, :transaction_type, name: "idx_coin_transactions_type"
    end
  end

  def down
    drop_table :coin_transactions if table_exists?(:coin_transactions)
  end
end