# frozen_string_literal: true

module ::MyPluginModule
  class CoinPaymentOrder < ActiveRecord::Base
    self.table_name = 'coin_payment_orders'

    # 订单过期时间（秒）
    ORDER_EXPIRE_SECONDS = 120  # 2分钟

    belongs_to :user
    belongs_to :recharge_package, 
               class_name: 'MyPluginModule::CoinRechargePackage', 
               foreign_key: :recharge_package_id,
               optional: true

    # 状态枚举: 0=pending, 1=paid, 2=failed, 3=expired
    enum :status, { pending: 0, paid: 1, failed: 2, expired: 3 }

    validates :out_trade_no, presence: true, uniqueness: true
    validates :coin_amount, presence: true, numericality: { greater_than: 0, only_integer: true }
    validates :original_price, presence: true, numericality: { greater_than: 0 }
    validates :actual_price, presence: true, numericality: { greater_than: 0 }
    validates :discount_rate, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
    validates :payment_type, presence: true

    scope :recent, -> { order(created_at: :desc) }
    scope :by_user, ->(user_id) { where(user_id: user_id) }
    scope :pending_expired, -> { pending.where("created_at < ?", ORDER_EXPIRE_SECONDS.seconds.ago) }

    def mark_as_paid!(trade_no)
      update!(
        status: :paid,
        trade_no: trade_no,
        paid_at: Time.current
      )
    end

    def mark_as_expired!
      update!(status: :expired)
    end

    def mark_as_failed!
      update!(status: :failed)
    end

    def can_process_callback?
      pending? && !expired_by_time?
    end

    # 检查订单是否已超时（基于创建时间）
    def expired_by_time?
      created_at < ORDER_EXPIRE_SECONDS.seconds.ago
    end

    # 获取剩余秒数
    def remaining_seconds
      return 0 if !pending? || expired_by_time?
      expire_at = created_at + ORDER_EXPIRE_SECONDS.seconds
      [(expire_at - Time.current).to_i, 0].max
    end
  end
end
