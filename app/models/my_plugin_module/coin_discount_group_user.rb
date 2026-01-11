# frozen_string_literal: true

module ::MyPluginModule
  class CoinDiscountGroupUser < ActiveRecord::Base
    self.table_name = 'coin_discount_group_users'

    belongs_to :discount_group, 
               class_name: 'MyPluginModule::CoinDiscountGroup', 
               foreign_key: :discount_group_id
    belongs_to :user

    validates :user_id, uniqueness: { scope: :discount_group_id, message: "已在该折扣组中" }

    scope :by_user, ->(user_id) { where(user_id: user_id) }
    scope :by_group, ->(group_id) { where(discount_group_id: group_id) }
  end
end
