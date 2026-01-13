# frozen_string_literal: true

class UpdateInvoiceFields < ActiveRecord::Migration[7.0]
  def up
    # 电子邮箱（个人/企业联系人邮箱）
    unless column_exists?(:coin_invoice_requests, :email)
      add_column :coin_invoice_requests, :email, :string, default: nil, null: true
    end

    # 电话（个人/企业联系人电话）
    unless column_exists?(:coin_invoice_requests, :phone)
      add_column :coin_invoice_requests, :phone, :string, default: nil, null: true
    end

    # 账单地址
    unless column_exists?(:coin_invoice_requests, :billing_address)
      add_column :coin_invoice_requests, :billing_address, :text, default: nil, null: true
    end

    # 联系人姓名（企业发票用）
    unless column_exists?(:coin_invoice_requests, :contact_name)
      add_column :coin_invoice_requests, :contact_name, :string, default: nil, null: true
    end

    # 移除不再需要的身份证号字段
    if column_exists?(:coin_invoice_requests, :id_number)
      remove_column :coin_invoice_requests, :id_number
    end
  end

  def down
    # 恢复身份证号字段
    unless column_exists?(:coin_invoice_requests, :id_number)
      add_column :coin_invoice_requests, :id_number, :string, default: nil, null: true
    end

    remove_column :coin_invoice_requests, :email if column_exists?(:coin_invoice_requests, :email)
    remove_column :coin_invoice_requests, :phone if column_exists?(:coin_invoice_requests, :phone)
    remove_column :coin_invoice_requests, :billing_address if column_exists?(:coin_invoice_requests, :billing_address)
    remove_column :coin_invoice_requests, :contact_name if column_exists?(:coin_invoice_requests, :contact_name)
  end
end
