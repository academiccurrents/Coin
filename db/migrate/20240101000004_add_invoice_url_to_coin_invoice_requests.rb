# frozen_string_literal: true

class AddInvoiceUrlToCoinInvoiceRequests < ActiveRecord::Migration[6.0]
  def up
    unless column_exists?(:coin_invoice_requests, :invoice_url)
      add_column :coin_invoice_requests, :invoice_url, :string, default: nil, null: true
    end
  end

  def down
    if column_exists?(:coin_invoice_requests, :invoice_url)
      remove_column :coin_invoice_requests, :invoice_url
    end
  end
end