# frozen_string_literal: true

class AddOutTradeNoToCoinTransactions < ActiveRecord::Migration[7.0]
  def up
    # 添加订单号字段，用于关联支付订单
    unless column_exists?(:coin_transactions, :out_trade_no)
      add_column :coin_transactions, :out_trade_no, :string, default: nil, null: true
    end

    # 添加索引
    unless index_exists?(:coin_transactions, :out_trade_no, name: "idx_coin_transactions_out_trade_no")
      add_index :coin_transactions, :out_trade_no, name: "idx_coin_transactions_out_trade_no"
    end
  end

  def down
    remove_index :coin_transactions, name: "idx_coin_transactions_out_trade_no" if index_exists?(:coin_transactions, :out_trade_no, name: "idx_coin_transactions_out_trade_no")
    remove_column :coin_transactions, :out_trade_no if column_exists?(:coin_transactions, :out_trade_no)
  end
end
