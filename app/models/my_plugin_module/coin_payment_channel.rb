# frozen_string_literal: true

module ::MyPluginModule
  class CoinPaymentChannel < ActiveRecord::Base
    self.table_name = "coin_payment_channels"

    validates :channel_type, presence: true, uniqueness: true
    validates :name, presence: true
    validates :icon, presence: true

    scope :enabled, -> { where(enabled: true) }
    scope :ordered, -> { order(display_order: :asc, id: :asc) }

    # 获取所有启用的渠道
    def self.enabled_channels
      enabled.ordered.map do |channel|
        {
          type: channel.channel_type,
          name: channel.name,
          icon: channel.icon
        }
      end
    end

    # 检查是否有任何启用的渠道
    def self.any_enabled?
      enabled.exists?
    end
  end
end
