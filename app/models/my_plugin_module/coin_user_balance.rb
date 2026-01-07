# frozen_string_literal: true

module ::MyPluginModule
  class CoinUserBalance < ::ActiveRecord::Base
    self.table_name = "coin_user_balances"

    belongs_to :user

    validates :user_id, presence: true, uniqueness: true
    validates :balance, presence: true, numericality: { only_integer: true }

    def self.get_or_create(user_id)
      find_or_create_by(user_id: user_id) do |balance|
        balance.balance = 0
      end
    end
  end
end