# frozen_string_literal: true

module ::MyPluginModule
  class CoinInvoiceRequest < ::ActiveRecord::Base
    self.table_name = "coin_invoice_requests"

    belongs_to :user

    validates :user_id, presence: true
    validates :amount, presence: true, numericality: { only_integer: true, greater_than: 0 }
    validates :status, presence: true

    STATUSES = %w[pending completed].freeze

    scope :recent, -> { order(created_at: :desc) }
    scope :by_user, ->(user_id) { where(user_id: user_id) }
    scope :by_status, ->(status) { where(status: status) }

    def pending?
      status == "pending"
    end

    def completed?
      status == "completed"
    end

    def has_invoice_url?
      invoice_url.present?
    end
  end
end