# frozen_string_literal: true

module ::MyPluginModule
  class CoinDiscountGroup < ActiveRecord::Base
    self.table_name = 'coin_discount_groups'

    has_many :discount_group_users, 
             class_name: 'MyPluginModule::CoinDiscountGroupUser', 
             foreign_key: :discount_group_id,
             dependent: :destroy

    validates :name, presence: true, uniqueness: true
    validates :discount_rate, presence: true, 
              numericality: { greater_than: 0, less_than_or_equal_to: 100, only_integer: true }

    scope :ordered, -> { order(discount_rate: :asc, name: :asc) }

    def user_count
      discount_group_users.count
    end

    def user_ids
      discount_group_users.pluck(:user_id)
    end
  end
end
