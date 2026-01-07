# frozen_string_literal: true

module ::MyPluginModule
  class CoinTransaction < ::ActiveRecord::Base
    self.table_name = "coin_transactions"

    belongs_to :user

    validates :user_id, presence: true
    validates :amount, presence: true, numericality: { only_integer: true }
    validates :balance_after, presence: true, numericality: { only_integer: true }
    validates :reason, presence: true
    validates :transaction_type, presence: true

    scope :recent, -> { order(created_at: :desc) }
    scope :by_user, ->(user_id) { where(user_id: user_id) }
    scope :by_type, ->(type) { where(transaction_type: type) }

    TRANSACTION_TYPES = %w[recharge admin_adjust consumption].freeze
  end
end