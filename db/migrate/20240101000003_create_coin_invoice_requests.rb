# frozen_string_literal: true

class CreateCoinInvoiceRequests < ActiveRecord::Migration[6.0]
  def up
    unless table_exists?(:coin_invoice_requests)
      create_table :coin_invoice_requests do |t|
        t.integer :user_id, null: false
        t.integer :amount, null: false
        t.string :status, null: false, default: 'pending'
        t.text :reason
        t.text :admin_note
        t.timestamps null: false
      end
    end

    unless index_exists?(:coin_invoice_requests, :user_id, name: "idx_coin_invoice_requests_user_id")
      add_index :coin_invoice_requests, :user_id, name: "idx_coin_invoice_requests_user_id"
    end

    unless index_exists?(:coin_invoice_requests, :status, name: "idx_coin_invoice_requests_status")
      add_index :coin_invoice_requests, :status, name: "idx_coin_invoice_requests_status"
    end

    unless index_exists?(:coin_invoice_requests, [:user_id, :created_at], name: "idx_coin_invoice_requests_uid_created")
      add_index :coin_invoice_requests, [:user_id, :created_at], name: "idx_coin_invoice_requests_uid_created"
    end
  end

  def down
    drop_table :coin_invoice_requests if table_exists?(:coin_invoice_requests)
  end
end