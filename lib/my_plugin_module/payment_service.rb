# frozen_string_literal: true

module ::MyPluginModule
  class PaymentService
    # 创建支付订单
    def self.create_order(user, package, payment_type)
      discount_rate = DiscountService.get_user_discount(user.id)
      actual_price = DiscountService.calculate_discounted_price(package.price, discount_rate)

      order = CoinPaymentOrder.create!(
        user_id: user.id,
        recharge_package_id: package.id,
        out_trade_no: generate_trade_no,
        coin_amount: package.coin_amount,
        original_price: package.price,
        actual_price: actual_price,
        discount_rate: discount_rate,
        payment_type: payment_type,
        status: :pending
      )

      Rails.logger.info "[支付] 创建订单: #{order.out_trade_no}, 用户: #{user.username}, 金额: #{actual_price}"

      order
    end

    # 创建自定义金额订单（不使用套餐）
    def self.create_custom_order(user, coin_amount, price, payment_type)
      discount_rate = DiscountService.get_user_discount(user.id)
      actual_price = DiscountService.calculate_discounted_price(price, discount_rate)

      order = CoinPaymentOrder.create!(
        user_id: user.id,
        recharge_package_id: nil,
        out_trade_no: generate_trade_no,
        coin_amount: coin_amount,
        original_price: price,
        actual_price: actual_price,
        discount_rate: discount_rate,
        payment_type: payment_type,
        status: :pending
      )

      Rails.logger.info "[支付] 创建自定义订单: #{order.out_trade_no}, 用户: #{user.username}, 金额: #{actual_price}"

      order
    end

    # 处理支付成功回调
    def self.process_payment_success(out_trade_no, trade_no, amount)
      ActiveRecord::Base.transaction do
        order = CoinPaymentOrder.find_by(out_trade_no: out_trade_no)

        unless order
          Rails.logger.error "[支付] 订单不存在: #{out_trade_no}"
          return { success: false, error: 'order_not_found' }
        end

        # 已处理的订单直接返回成功（幂等处理）
        if order.paid?
          Rails.logger.info "[支付] 订单已处理: #{out_trade_no}"
          return { success: true, message: 'already_processed' }
        end

        # 检查订单状态
        unless order.can_process_callback?
          Rails.logger.warn "[支付] 订单状态异常: #{out_trade_no}, 状态: #{order.status}"
          return { success: false, error: 'invalid_order_status' }
        end

        # 验证金额（允许0.01的误差）
        amount_diff = (order.actual_price.to_f - amount.to_f).abs
        if amount_diff > 0.01
          Rails.logger.error "[支付] 金额不匹配: #{out_trade_no}, 订单: #{order.actual_price}, 回调: #{amount}"
          return { success: false, error: 'amount_mismatch' }
        end

        # 更新订单状态
        order.mark_as_paid!(trade_no)

        # 增加用户余额
        coin_name = SiteSetting.coin_name || "硬币"
        CoinService.record_transaction(
          order.user_id,
          order.coin_amount,
          "充值 #{order.coin_amount} #{coin_name}",
          'recharge'
        )

        Rails.logger.info "[支付] 订单处理成功: #{out_trade_no}, 用户ID: #{order.user_id}, 硬币: #{order.coin_amount}"

        { success: true, order: order }
      end
    rescue => e
      Rails.logger.error "[支付] 处理回调异常: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      { success: false, error: e.message }
    end

    # 标记过期订单
    def self.expire_pending_orders
      expired_count = 0
      
      CoinPaymentOrder.pending_expired.find_each do |order|
        order.mark_as_expired!
        expired_count += 1
        Rails.logger.info "[支付] 订单已过期: #{order.out_trade_no}"
      end

      Rails.logger.info "[支付] 共标记 #{expired_count} 个过期订单" if expired_count > 0
      expired_count
    end

    # 获取用户订单列表
    def self.get_user_orders(user_id, limit: 20)
      CoinPaymentOrder.by_user(user_id).recent.limit(limit).map do |order|
        {
          id: order.id,
          out_trade_no: order.out_trade_no,
          coin_amount: order.coin_amount,
          original_price: order.original_price.to_f,
          actual_price: order.actual_price.to_f,
          discount_rate: order.discount_rate,
          payment_type: order.payment_type,
          status: order.status,
          created_at: order.created_at.iso8601,
          paid_at: order.paid_at&.iso8601
        }
      end
    end

    # 查询订单状态
    def self.get_order_status(out_trade_no, user_id)
      order = CoinPaymentOrder.find_by(out_trade_no: out_trade_no, user_id: user_id)
      return nil unless order

      {
        status: order.status,
        paid: order.paid?,
        coin_amount: order.coin_amount
      }
    end

    private

    # 生成唯一订单号
    def self.generate_trade_no
      timestamp = Time.current.strftime('%Y%m%d%H%M%S')
      random = SecureRandom.hex(4).upcase
      "COIN#{timestamp}#{random}"
    end
  end
end
