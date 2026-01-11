# frozen_string_literal: true

class CreateCoinPaymentChannels < ActiveRecord::Migration[6.0]
  def up
    unless table_exists?(:coin_payment_channels)
      create_table :coin_payment_channels do |t|
        t.string :channel_type, null: false
        t.string :name, null: false
        t.string :icon, null: false
        t.boolean :enabled, null: false, default: true
        t.integer :display_order, null: false, default: 0
        t.timestamps null: false
      end
    end

    unless index_exists?(:coin_payment_channels, :channel_type, name: "idx_coin_payment_channels_type")
      add_index :coin_payment_channels, :channel_type, unique: true, name: "idx_coin_payment_channels_type"
    end

    unless index_exists?(:coin_payment_channels, :display_order, name: "idx_coin_payment_channels_order")
      add_index :coin_payment_channels, :display_order, name: "idx_coin_payment_channels_order"
    end

    # 初始化默认渠道
    seed_default_channels
  end

  def down
    drop_table :coin_payment_channels if table_exists?(:coin_payment_channels)
  end

  private

  def seed_default_channels
    default_channels = [
      { channel_type: 'alipay', name: '支付宝', icon: 'alipay', display_order: 1, enabled: true },
      { channel_type: 'wxpay', name: '微信支付', icon: 'wxpay', display_order: 2, enabled: true },
      { channel_type: 'paypal', name: 'PayPal', icon: 'paypal', display_order: 3, enabled: true }
    ]

    default_channels.each do |channel|
      execute <<-SQL
        INSERT INTO coin_payment_channels (channel_type, name, icon, display_order, enabled, created_at, updated_at)
        SELECT '#{channel[:channel_type]}', '#{channel[:name]}', '#{channel[:icon]}', #{channel[:display_order]}, #{channel[:enabled]}, NOW(), NOW()
        WHERE NOT EXISTS (SELECT 1 FROM coin_payment_channels WHERE channel_type = '#{channel[:channel_type]}')
      SQL
    end
  end
end
