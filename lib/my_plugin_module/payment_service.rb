# frozen_string_literal: true

module ::MyPluginModule
  class PaymentService
    # 创建支付订单
    def self.create_order(user, package, payment_type)
      discount_rate = DiscountService.get_user_discount(user.id)
      actual_price = DiscountService.calculate_discounted_price(package.price, discount_rate)

      CoinPaymentOrder.create!(
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
    end

    # 创建自定义金额订单（不使用套餐）
    def self.create_custom_order(user, coin_amount, price, payment_type)
      discount_rate = DiscountService.get_user_discount(user.id)
      actual_price = DiscountService.calculate_discounted_price(price, discount_rate)

      CoinPaymentOrder.create!(
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
    end

    # 处理支付成功回调
    def self.process_payment_success(out_trade_no, trade_no, amount)
      ActiveRecord::Base.transaction do
        order = CoinPaymentOrder.find_by(out_trade_no: out_trade_no)
        return { success: false, error: 'order_not_found' } unless order

        # 已处理的订单直接返回成功（幂等处理）
        return { success: true, message: 'already_processed' } if order.paid?

        # 检查订单状态和是否超时
        unless order.can_process_callback?
          # 如果订单超时，标记为过期
          order.mark_as_expired! if order.pending? && order.expired_by_time?
          return { success: false, error: 'order_expired_or_invalid' }
        end

        # 验证金额（允许0.01的误差）
        amount_diff = (order.actual_price.to_f - amount.to_f).abs
        return { success: false, error: 'amount_mismatch' } if amount_diff > 0.01

        # 更新订单状态
        order.mark_as_paid!(trade_no)

        # 增加用户余额
        coin_name = SiteSetting.coin_name || "Coin"
        CoinService.record_transaction(
          order.user_id,
          order.coin_amount,
          "Recharge #{order.coin_amount} #{coin_name}",
          'recharge',
          out_trade_no: order.out_trade_no
        )

        { success: true, order: order }
      end
    rescue => e
      { success: false, error: e.message }
    end

    # 获取用户最新的待支付订单
    def self.get_pending_order(user_id)
      order = CoinPaymentOrder.by_user(user_id).pending.recent.first
      return nil unless order

      # 检查是否超时
      if order.expired_by_time?
        order.mark_as_expired!
        return nil
      end

      {
        out_trade_no: order.out_trade_no,
        coin_amount: order.coin_amount,
        actual_price: order.actual_price.to_f,
        payment_type: order.payment_type,
        remaining_seconds: order.remaining_seconds,
        pay_url: order.pay_url,
        created_at: order.created_at.iso8601
      }
    end

    # 标记过期订单
    def self.expire_pending_orders
      expired_count = 0
      
      CoinPaymentOrder.pending_expired.find_each do |order|
        order.mark_as_expired!
        expired_count += 1
      end

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

      # 检查是否超时
      if order.pending? && order.expired_by_time?
        order.mark_as_expired!
      end

      {
        status: order.status,
        paid: order.paid?,
        expired: order.expired?,
        coin_amount: order.coin_amount,
        remaining_seconds: order.remaining_seconds
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
