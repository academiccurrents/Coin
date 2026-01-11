# frozen_string_literal: true

module ::MyPluginModule
  class CoinRechargePackage < ActiveRecord::Base
    self.table_name = 'coin_recharge_packages'

    validates :coin_amount, presence: true, numericality: { greater_than: 0, only_integer: true }
    validates :price, presence: true, numericality: { greater_than: 0 }
    validates :display_order, presence: true, numericality: { only_integer: true }

    scope :active, -> { where(active: true) }
    scope :ordered, -> { order(display_order: :asc, id: :asc) }
    scope :recommended, -> { where(recommended: true) }

    def self.list_for_user
      active.ordered
    end
  end
end
