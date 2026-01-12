# frozen_string_literal: true

module ::MyPluginModule
  class CoinInvoiceRequest < ::ActiveRecord::Base
    self.table_name = "coin_invoice_requests"

    belongs_to :user

    validates :user_id, presence: true
    validates :amount, presence: true, numericality: { only_integer: true, greater_than: 0 }
    validates :status, presence: true

    # invoice_type 验证：只在列存在且有值时验证格式
    validates :invoice_type, inclusion: { in: %w[personal company] }, allow_nil: true, allow_blank: true,
              if: -> { self.class.column_names.include?('invoice_type') && invoice_type.present? }

    STATUSES = %w[pending completed rejected].freeze
    INVOICE_TYPES = %w[personal company].freeze
    MAX_RESUBMIT_COUNT = 2  # 最多重新申请2次

    scope :recent, -> { order(created_at: :desc) }
    scope :by_user, ->(user_id) { where(user_id: user_id) }
    scope :by_status, ->(status) { where(status: status) }
    scope :pending_list, -> { where(status: 'pending').order(created_at: :desc) }

    def pending?
      status == "pending"
    end

    def completed?
      status == "completed"
    end

    def rejected?
      status == "rejected"
    end

    def has_invoice_url?
      invoice_url.present?
    end

    def personal?
      return true unless respond_to?(:invoice_type) && invoice_type.present?
      invoice_type == "personal"
    end

    def company?
      return false unless respond_to?(:invoice_type) && invoice_type.present?
      invoice_type == "company"
    end

    # 是否可以编辑（待处理状态可以编辑）
    def editable?
      pending?
    end

    # 是否可以重新申请（被拒绝且重新申请次数未超限）
    def can_resubmit?
      return false unless self.class.column_names.include?('resubmit_count')
      rejected? && (resubmit_count || 0) < MAX_RESUBMIT_COUNT
    end

    # 剩余重新申请次数
    def remaining_resubmit_count
      return MAX_RESUBMIT_COUNT unless self.class.column_names.include?('resubmit_count')
      MAX_RESUBMIT_COUNT - (resubmit_count || 0)
    end
  end
end
