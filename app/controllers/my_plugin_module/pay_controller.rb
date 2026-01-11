# frozen_string_literal: true

module ::MyPluginModule
  class PayController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    before_action :ensure_logged_in, except: [:notify_callback, :return_callback]
    skip_before_action :verify_authenticity_token, only: [:notify_callback, :return_callback]

    # GET /coin/pay - 充值页面
    def index
      render "default/empty"
    end

    # GET /coin/pay/packages - 获取套餐列表和折扣信息
    def packages
      packages = CoinRechargePackage.active.ordered
      discount_rate = DiscountService.get_user_discount(current_user.id)
      balance = CoinService.get_user_balance(current_user.id)

      render_json_dump({
        success: true,
        packages: packages.map { |p| serialize_package(p, discount_rate) },
        discount_rate: discount_rate,
        has_discount: discount_rate < 100,
        balance: balance,
        coin_name: SiteSetting.coin_name || "硬币"
      })
    end

    # GET /coin/pay/channels - 获取支付渠道
    def payment_channels
      epay = EpayService.new
      channels = epay.get_payment_channels
      render_json_dump({ success: true, channels: channels })
    end

    # POST /coin/pay/create_order - 创建支付订单
    def create_order
      package_id = params[:package_id]
      payment_type = params[:payment_type] || 'alipay'
      mode = params[:mode] || 'page'

      package = CoinRechargePackage.active.find_by(id: package_id)
      return render_json_error("套餐不存在或已下架", status: 400) unless package

      order = PaymentService.create_order(current_user, package, payment_type)
      epay = EpayService.new

      coin_name = SiteSetting.coin_name || "硬币"
      pay_params = {
        type: payment_type,
        out_trade_no: order.out_trade_no,
        notify_url: "#{Discourse.base_url}/coin/pay/notify",
        return_url: "#{Discourse.base_url}/coin/pay/return",
        name: "充值 #{order.coin_amount} #{coin_name}",
        money: order.actual_price.to_s
      }

      if mode == 'qrcode'
        result = epay.create_api_pay(pay_params)
        if result[:success]
          # 保存 pay_url 到订单
          order.update(pay_url: result[:url]) if result[:url].present?
          render_json_dump({
            success: true,
            order_id: order.id,
            out_trade_no: order.out_trade_no,
            qrcode: result[:qrcode],
            pay_url: result[:url]
          })
        else
          render_json_error(result[:error] || "创建支付失败", status: 500)
        end
      else
        result = epay.create_page_pay(pay_params)
        # 保存 pay_url 到订单
        order.update(pay_url: result[:url]) if result[:url].present?
        render_json_dump({
          success: true,
          order_id: order.id,
          out_trade_no: order.out_trade_no,
          pay_url: result[:url]
        })
      end
    end

    # POST/GET /coin/pay/notify - 异步回调处理
    def notify_callback
      epay = EpayService.new
      callback_params = params.to_unsafe_h.except(:controller, :action)

      # 验证签名
      unless epay.verify_callback(callback_params)
        render plain: 'fail'
        return
      end

      # 检查交易状态
      unless params[:trade_status] == 'TRADE_SUCCESS'
        render plain: 'success'
        return
      end

      # 处理支付成功
      result = PaymentService.process_payment_success(
        params[:out_trade_no],
        params[:trade_no],
        params[:money]
      )

      render plain: result[:success] ? 'success' : 'fail'
    end

    # GET /coin/pay/return - 同步回调处理（易支付支付完成后跳转回来）
    def return_callback
      epay = EpayService.new
      callback_params = params.to_unsafe_h.except(:controller, :action)

      if epay.verify_callback(callback_params) && params[:trade_status] == 'TRADE_SUCCESS'
        PaymentService.process_payment_success(
          params[:out_trade_no],
          params[:trade_no],
          params[:money]
        )
        redirect_to "/coin/pay?payment=success", allow_other_host: false
      else
        redirect_to "/coin/pay?payment=failed", allow_other_host: false
      end
    end

    # GET /coin/pay/order_status - 查询订单状态
    def order_status
      out_trade_no = params[:out_trade_no]
      return render_json_error("订单号不能为空", status: 400) unless out_trade_no.present?

      result = PaymentService.get_order_status(out_trade_no, current_user.id)
      return render_json_error("订单不存在", status: 404) unless result

      render_json_dump({
        success: true,
        status: result[:status],
        paid: result[:paid],
        expired: result[:expired],
        coin_amount: result[:coin_amount],
        remaining_seconds: result[:remaining_seconds]
      })
    end

    # GET /coin/pay/pending_order - 获取用户最新的待支付订单
    def pending_order
      result = PaymentService.get_pending_order(current_user.id)
      
      if result
        render_json_dump({ success: true, has_pending: true, order: result })
      else
        render_json_dump({ success: true, has_pending: false })
      end
    end

    # GET /coin/pay/orders - 获取用户订单列表
    def orders
      limit = (params[:limit] || 20).to_i
      orders = PaymentService.get_user_orders(current_user.id, limit: limit)
      render_json_dump({ success: true, orders: orders })
    end

    # POST /coin/pay/create_custom_order - 创建自定义金额订单
    def create_custom_order
      coin_amount = params[:coin_amount].to_i
      payment_type = params[:payment_type] || 'alipay'
      mode = params[:mode] || 'page'

      return render_json_error("充值数量不能小于1", status: 400) if coin_amount < 1
      return render_json_error("单次充值不能超过10000", status: 400) if coin_amount > 10000

      price = coin_amount.to_d
      order = PaymentService.create_custom_order(current_user, coin_amount, price, payment_type)
      epay = EpayService.new

      coin_name = SiteSetting.coin_name || "硬币"
      pay_params = {
        type: payment_type,
        out_trade_no: order.out_trade_no,
        notify_url: "#{Discourse.base_url}/coin/pay/notify",
        return_url: "#{Discourse.base_url}/coin/pay/return",
        name: "充值 #{order.coin_amount} #{coin_name}",
        money: order.actual_price.to_s
      }

      if mode == 'qrcode'
        result = epay.create_api_pay(pay_params)
        if result[:success]
          # 保存 pay_url 到订单
          order.update(pay_url: result[:url]) if result[:url].present?
          render_json_dump({
            success: true,
            order_id: order.id,
            out_trade_no: order.out_trade_no,
            qrcode: result[:qrcode],
            pay_url: result[:url]
          })
        else
          render_json_error(result[:error] || "创建支付失败", status: 500)
        end
      else
        result = epay.create_page_pay(pay_params)
        # 保存 pay_url 到订单
        order.update(pay_url: result[:url]) if result[:url].present?
        render_json_dump({
          success: true,
          order_id: order.id,
          out_trade_no: order.out_trade_no,
          pay_url: result[:url]
        })
      end
    end

    # ==================== 管理员套餐管理 ====================

    def admin_packages
      ensure_admin!
      packages = CoinRechargePackage.ordered.map { |p| serialize_admin_package(p) }
      render_json_dump({ success: true, packages: packages })
    end

    def create_package
      ensure_admin!
      package = CoinRechargePackage.create!(
        coin_amount: params[:coin_amount].to_i,
        price: params[:price].to_d,
        description: params[:description],
        display_order: params[:display_order].to_i,
        recommended: params[:recommended] == true || params[:recommended] == 'true',
        active: params[:active] != false && params[:active] != 'false'
      )
      render_json_dump({ success: true, package: serialize_admin_package(package) })
    end

    def update_package
      ensure_admin!
      package = CoinRechargePackage.find(params[:id])
      
      update_params = {}
      update_params[:coin_amount] = params[:coin_amount].to_i if params[:coin_amount].present?
      update_params[:price] = params[:price].to_d if params[:price].present?
      update_params[:description] = params[:description] if params.key?(:description)
      update_params[:display_order] = params[:display_order].to_i if params[:display_order].present?
      update_params[:recommended] = params[:recommended] == true || params[:recommended] == 'true' if params.key?(:recommended)
      update_params[:active] = params[:active] == true || params[:active] == 'true' if params.key?(:active)

      package.update!(update_params)
      render_json_dump({ success: true, package: serialize_admin_package(package) })
    end

    def delete_package
      ensure_admin!
      CoinRechargePackage.find(params[:id]).destroy!
      render_json_dump({ success: true })
    end

    def seed_packages
      ensure_admin!
      default_packages = [
        { coin_amount: 10, price: 10, description: "入门套餐", display_order: 1, recommended: false },
        { coin_amount: 20, price: 20, description: "基础套餐", display_order: 2, recommended: false },
        { coin_amount: 50, price: 50, description: "热门套餐", display_order: 3, recommended: true },
        { coin_amount: 100, price: 100, description: "超值套餐", display_order: 4, recommended: false }
      ]

      created = []
      default_packages.each do |pkg_data|
        next if CoinRechargePackage.exists?(coin_amount: pkg_data[:coin_amount])
        package = CoinRechargePackage.create!(pkg_data.merge(active: true))
        created << serialize_admin_package(package)
      end

      render_json_dump({ success: true, created_count: created.length, packages: created })
    end

    # ==================== 管理员渠道管理 ====================

    def admin_channels
      ensure_admin!
      channels = CoinPaymentChannel.ordered.map { |c| serialize_admin_channel(c) }
      render_json_dump({ success: true, channels: channels })
    end

    def update_channel
      ensure_admin!
      channel = CoinPaymentChannel.find(params[:id])
      
      update_params = {}
      update_params[:name] = params[:name] if params[:name].present?
      update_params[:enabled] = params[:enabled] == true || params[:enabled] == 'true' if params.key?(:enabled)
      update_params[:display_order] = params[:display_order].to_i if params[:display_order].present?

      channel.update!(update_params)
      render_json_dump({ success: true, channel: serialize_admin_channel(channel) })
    end

    def seed_channels
      ensure_admin!
      default_channels = [
        { channel_type: 'alipay', name: '支付宝', icon: 'alipay', display_order: 1 },
        { channel_type: 'wxpay', name: '微信支付', icon: 'wxpay', display_order: 2 },
        { channel_type: 'paypal', name: 'PayPal', icon: 'paypal', display_order: 3 }
      ]

      created = []
      default_channels.each do |ch_data|
        next if CoinPaymentChannel.exists?(channel_type: ch_data[:channel_type])
        channel = CoinPaymentChannel.create!(ch_data.merge(enabled: true))
        created << serialize_admin_channel(channel)
      end

      render_json_dump({ success: true, created_count: created.length, channels: created })
    end

    # ==================== 管理员折扣管理 ====================

    def admin_discount_groups
      ensure_admin!
      groups = CoinDiscountGroup.ordered.map { |g| serialize_discount_group(g) }
      render_json_dump({ success: true, groups: groups })
    end

    def create_discount_group
      ensure_admin!
      group = CoinDiscountGroup.create!(
        name: params[:name],
        discount_rate: params[:discount_rate].to_i,
        description: params[:description]
      )
      render_json_dump({ success: true, group: serialize_discount_group(group) })
    end

    def update_discount_group
      ensure_admin!
      group = CoinDiscountGroup.find(params[:id])
      
      update_params = {}
      update_params[:name] = params[:name] if params[:name].present?
      update_params[:discount_rate] = params[:discount_rate].to_i if params[:discount_rate].present?
      update_params[:description] = params[:description] if params.key?(:description)

      group.update!(update_params)
      render_json_dump({ success: true, group: serialize_discount_group(group) })
    end

    def delete_discount_group
      ensure_admin!
      CoinDiscountGroup.find(params[:id]).destroy!
      render_json_dump({ success: true })
    end

    def discount_group_users
      ensure_admin!
      group = CoinDiscountGroup.find(params[:id])
      users = DiscountService.get_group_users(group.id, limit: 200)
      render_json_dump({ success: true, users: users })
    end

    def add_discount_user
      ensure_admin!
      username = params[:username]
      group_id = params[:group_id]

      user = User.find_by_username(username)
      return render_json_error("用户不存在", status: 404) unless user

      group = CoinDiscountGroup.find(group_id)
      
      if DiscountService.user_in_group?(user.id, group.id)
        return render_json_error("用户已在该折扣组中", status: 400)
      end

      DiscountService.add_user_to_group(user.id, group.id)
      render_json_dump({ 
        success: true, 
        user: {
          id: user.id,
          username: user.username,
          avatar_url: user.avatar_template.gsub('{size}', '45')
        }
      })
    end

    def remove_discount_user
      ensure_admin!
      user_id = params[:user_id]
      group_id = params[:group_id]

      DiscountService.remove_user_from_group(user_id, group_id)
      render_json_dump({ success: true })
    end

    def search_users
      ensure_admin!
      term = params[:term]
      return render_json_dump({ success: true, users: [] }) if term.blank?

      users = User.where("username ILIKE ?", "%#{term}%").limit(10).map do |user|
        {
          id: user.id,
          username: user.username,
          avatar_url: user.avatar_template.gsub('{size}', '45')
        }
      end
      render_json_dump({ success: true, users: users })
    end

    private

    def ensure_admin!
      raise Discourse::InvalidAccess unless current_user&.admin?
    end

    def serialize_package(package, discount_rate)
      actual_price = DiscountService.calculate_discounted_price(package.price, discount_rate)
      {
        id: package.id,
        coin_amount: package.coin_amount,
        original_price: package.price.to_f,
        actual_price: actual_price,
        description: package.description,
        recommended: package.recommended,
        display_order: package.display_order
      }
    end

    def serialize_admin_package(package)
      {
        id: package.id,
        coin_amount: package.coin_amount,
        price: package.price.to_f,
        description: package.description,
        display_order: package.display_order,
        recommended: package.recommended,
        active: package.active,
        created_at: package.created_at.iso8601
      }
    end

    def serialize_admin_channel(channel)
      {
        id: channel.id,
        channel_type: channel.channel_type,
        name: channel.name,
        icon: channel.icon,
        enabled: channel.enabled,
        display_order: channel.display_order
      }
    end

    def serialize_discount_group(group)
      {
        id: group.id,
        name: group.name,
        discount_rate: group.discount_rate,
        description: group.description,
        user_count: group.user_count,
        created_at: group.created_at.iso8601
      }
    end
  end
end
