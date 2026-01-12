# frozen_string_literal: true

class AddInvoiceDetailsToCoinInvoiceRequests < ActiveRecord::Migration[6.0]
  def up
    # 发票类型：personal（个人）/ company（企业）
    unless column_exists?(:coin_invoice_requests, :invoice_type)
      add_column :coin_invoice_requests, :invoice_type, :string, default: 'personal', null: false
    end

    # 发票抬头（个人姓名或公司名称）
    unless column_exists?(:coin_invoice_requests, :invoice_title)
      add_column :coin_invoice_requests, :invoice_title, :string, default: nil, null: true
    end

    # 身份证号码（个人发票）
    unless column_exists?(:coin_invoice_requests, :id_number)
      add_column :coin_invoice_requests, :id_number, :string, default: nil, null: true
    end

    # 纳税人识别号（企业发票）
    unless column_exists?(:coin_invoice_requests, :tax_number)
      add_column :coin_invoice_requests, :tax_number, :string, default: nil, null: true
    end

    # 拒绝理由
    unless column_exists?(:coin_invoice_requests, :reject_reason)
      add_column :coin_invoice_requests, :reject_reason, :text, default: nil, null: true
    end

    # 关联的订单号
    unless column_exists?(:coin_invoice_requests, :out_trade_no)
      add_column :coin_invoice_requests, :out_trade_no, :string, default: nil, null: true
    end

    # 添加索引
    unless index_exists?(:coin_invoice_requests, :invoice_type, name: "idx_coin_invoice_type")
      add_index :coin_invoice_requests, :invoice_type, name: "idx_coin_invoice_type"
    end

    unless index_exists?(:coin_invoice_requests, :out_trade_no, name: "idx_coin_invoice_out_trade_no")
      add_index :coin_invoice_requests, :out_trade_no, name: "idx_coin_invoice_out_trade_no"
    end
  end

  def down
    remove_index :coin_invoice_requests, name: "idx_coin_invoice_type" if index_exists?(:coin_invoice_requests, :invoice_type, name: "idx_coin_invoice_type")
    remove_index :coin_invoice_requests, name: "idx_coin_invoice_out_trade_no" if index_exists?(:coin_invoice_requests, :out_trade_no, name: "idx_coin_invoice_out_trade_no")
    
    remove_column :coin_invoice_requests, :invoice_type if column_exists?(:coin_invoice_requests, :invoice_type)
    remove_column :coin_invoice_requests, :invoice_title if column_exists?(:coin_invoice_requests, :invoice_title)
    remove_column :coin_invoice_requests, :id_number if column_exists?(:coin_invoice_requests, :id_number)
    remove_column :coin_invoice_requests, :tax_number if column_exists?(:coin_invoice_requests, :tax_number)
    remove_column :coin_invoice_requests, :reject_reason if column_exists?(:coin_invoice_requests, :reject_reason)
    remove_column :coin_invoice_requests, :out_trade_no if column_exists?(:coin_invoice_requests, :out_trade_no)
  end
end
