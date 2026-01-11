# frozen_string_literal: true

module ::MyPluginModule
  class PayController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    before_action :ensure_logged_in, except: [:notify_callback]
    skip_before_action :verify_authenticity_token, only: [:notify_callback]

    # GET /coin/pay - 充值页面
    def index
      render "default/empty"
    rescue => e
      Rails.logger.error "[支付] 页面错误: #{e.message}"
      render plain: "Error: #{e.message}", status: 500
    end

    # GET /coin/pay/packages - 获取套餐列表和折扣信息
    def packages
      begin
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
      rescue => e
        Rails.logger.error "[支付] 获取套餐失败: #{e.message}"
        render_json_error("获取套餐失败", status: 500)
      end
    end

    # GET /coin/pay/channels - 获取支付渠道
    def payment_channels
      begin
        epay = EpayService.new
        channels = epay.get_payment_channels

        render_json_dump({
          success: true,
          channels: channels
        })
      rescue => e
        Rails.logger.error "[支付] 获取支付渠道失败: #{e.message}"
        render_json_error("获取支付渠道失败", status: 500)
      end
    end

    # POST /coin/pay/create_order - 创建支付订单
    def create_order
      begin
        package_id = params[:package_id]
        payment_type = params[:payment_type] || 'alipay'
        mode = params[:mode] || 'page' # page 或 qrcode

        package = CoinRechargePackage.active.find_by(id: package_id)
        unless package
          render_json_error("套餐不存在或已下架", status: 400)
          return
        end

        # 创建订单
        order = PaymentService.create_order(current_user, package, payment_type)
        epay = EpayService.new

        # 构建支付参数
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
          # API支付，获取二维码
          result = epay.create_api_pay(pay_params)
          if result[:success]
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
          # 页面跳转支付
          result = epay.create_page_pay(pay_params)
          render_json_dump({
            success: true,
            order_id: order.id,
            out_trade_no: order.out_trade_no,
            pay_url: result[:url]
          })
        end
      rescue => e
        Rails.logger.error "[支付] 创建订单失败: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
        render_json_error("创建订单失败: #{e.message}", status: 500)
      end
    end


    # POST /coin/pay/notify - 异步回调处理
    def notify_callback
      begin
        Rails.logger.info "[支付] 收到异步回调: #{params.to_unsafe_h}"
        
        epay = EpayService.new
        callback_params = params.to_unsafe_h.except(:controller, :action)

        # 验证签名
        unless epay.verify_callback(callback_params)
          Rails.logger.error "[支付] 回调验签失败: #{callback_params}"
          render plain: 'fail'
          return
        end

        # 检查交易状态
        trade_status = params[:trade_status]
        unless trade_status == 'TRADE_SUCCESS'
          Rails.logger.info "[支付] 交易状态非成功: #{trade_status}"
          render plain: 'success' # 返回success避免重复通知
          return
        end

        # 处理支付成功
        result = PaymentService.process_payment_success(
          params[:out_trade_no],
          params[:trade_no],
          params[:money]
        )

        if result[:success]
          Rails.logger.info "[支付] 回调处理成功: #{params[:out_trade_no]}"
          render plain: 'success'
        else
          Rails.logger.error "[支付] 回调处理失败: #{result[:error]}"
          render plain: 'fail'
        end
      rescue => e
        Rails.logger.error "[支付] 回调处理异常: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
        render plain: 'fail'
      end
    end

    # GET /coin/pay/return - 同步回调处理
    def return_callback
      begin
        Rails.logger.info "[支付] 收到同步回调: #{params.to_unsafe_h}"
        
        epay = EpayService.new
        callback_params = params.to_unsafe_h.except(:controller, :action)

        # 验证签名
        if epay.verify_callback(callback_params) && params[:trade_status] == 'TRADE_SUCCESS'
          # 同步回调也处理支付成功（防止异步回调延迟或失败）
          result = PaymentService.process_payment_success(
            params[:out_trade_no],
            params[:trade_no],
            params[:money]
          )
          
          if result[:success]
            Rails.logger.info "[支付] 同步回调处理成功: #{params[:out_trade_no]}"
          else
            Rails.logger.warn "[支付] 同步回调处理结果: #{result[:error]}"
          end
          
          redirect_to "/coin?payment=success"
        else
          Rails.logger.warn "[支付] 同步回调验签失败或状态非成功"
          redirect_to "/coin?payment=failed"
        end
      rescue => e
        Rails.logger.error "[支付] 同步回调异常: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
        redirect_to "/coin?payment=error"
      end
    end

    # GET /coin/pay/order_status - 查询订单状态
    def order_status
      begin
        out_trade_no = params[:out_trade_no]
        
        unless out_trade_no.present?
          render_json_error("订单号不能为空", status: 400)
          return
        end

        result = PaymentService.get_order_status(out_trade_no, current_user.id)
        
        unless result
          render_json_error("订单不存在", status: 404)
          return
        end

        render_json_dump({
          success: true,
          status: result[:status],
          paid: result[:paid],
          coin_amount: result[:coin_amount]
        })
      rescue => e
        Rails.logger.error "[支付] 查询订单状态失败: #{e.message}"
        render_json_error("查询订单状态失败", status: 500)
      end
    end

    # GET /coin/pay/orders - 获取用户订单列表
    def orders
      begin
        limit = (params[:limit] || 20).to_i
        orders = PaymentService.get_user_orders(current_user.id, limit: limit)

        render_json_dump({
          success: true,
          orders: orders
        })
      rescue => e
        Rails.logger.error "[支付] 获取订单列表失败: #{e.message}"
        render_json_error("获取订单列表失败", status: 500)
      end
    end

    # POST /coin/pay/create_custom_order - 创建自定义金额订单
    def create_custom_order
      begin
        coin_amount = params[:coin_amount].to_i
        payment_type = params[:payment_type] || 'alipay'
        mode = params[:mode] || 'page'

        # 验证金额范围
        if coin_amount < 1
          render_json_error("充值数量不能小于1", status: 400)
          return
        end

        if coin_amount > 10000
          render_json_error("单次充值不能超过10000", status: 400)
          return
        end

        # 自定义充值：1硬币 = 1元
        price = coin_amount.to_d

        # 创建订单
        order = PaymentService.create_custom_order(current_user, coin_amount, price, payment_type)
        epay = EpayService.new

        # 构建支付参数
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
          render_json_dump({
            success: true,
            order_id: order.id,
            out_trade_no: order.out_trade_no,
            pay_url: result[:url]
          })
        end
      rescue => e
        Rails.logger.error "[支付] 创建自定义订单失败: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
        render_json_error("创建订单失败: #{e.message}", status: 500)
      end
    end

    # ==================== 管理员套餐管理 ====================

    # GET /coin/pay/admin/packages - 获取所有套餐（管理员）
    def admin_packages
      ensure_admin!

      packages = CoinRechargePackage.ordered.map do |p|
        {
          id: p.id,
          coin_amount: p.coin_amount,
          price: p.price.to_f,
          description: p.description,
          display_order: p.display_order,
          recommended: p.recommended,
          active: p.active,
          created_at: p.created_at.iso8601
        }
      end

      render_json_dump({ success: true, packages: packages })
    end

    # POST /coin/pay/admin/packages - 创建套餐
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

      render_json_dump({
        success: true,
        package: {
          id: package.id,
          coin_amount: package.coin_amount,
          price: package.price.to_f,
          description: package.description,
          display_order: package.display_order,
          recommended: package.recommended,
          active: package.active
        }
      })
    rescue => e
      render_json_error("创建套餐失败: #{e.message}", status: 500)
    end

    # PUT /coin/pay/admin/packages/:id - 更新套餐
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

      render_json_dump({
        success: true,
        package: {
          id: package.id,
          coin_amount: package.coin_amount,
          price: package.price.to_f,
          description: package.description,
          display_order: package.display_order,
          recommended: package.recommended,
          active: package.active
        }
      })
    rescue ActiveRecord::RecordNotFound
      render_json_error("套餐不存在", status: 404)
    rescue => e
      render_json_error("更新套餐失败: #{e.message}", status: 500)
    end

    # DELETE /coin/pay/admin/packages/:id - 删除套餐
    def delete_package
      ensure_admin!

      package = CoinRechargePackage.find(params[:id])
      package.destroy!

      render_json_dump({ success: true })
    rescue ActiveRecord::RecordNotFound
      render_json_error("套餐不存在", status: 404)
    rescue => e
      render_json_error("删除套餐失败: #{e.message}", status: 500)
    end

    # POST /coin/pay/admin/seed_packages - 一键添加示例套餐
    def seed_packages
      ensure_admin!

      # 默认套餐数据
      default_packages = [
        { coin_amount: 10, price: 10, description: "入门套餐", display_order: 1, recommended: false },
        { coin_amount: 20, price: 20, description: "基础套餐", display_order: 2, recommended: false },
        { coin_amount: 50, price: 50, description: "热门套餐", display_order: 3, recommended: true },
        { coin_amount: 100, price: 100, description: "超值套餐", display_order: 4, recommended: false }
      ]

      created = []
      default_packages.each do |pkg_data|
        # 检查是否已存在相同金额的套餐
        existing = CoinRechargePackage.find_by(coin_amount: pkg_data[:coin_amount])
        next if existing

        package = CoinRechargePackage.create!(pkg_data.merge(active: true))
        created << {
          id: package.id,
          coin_amount: package.coin_amount,
          price: package.price.to_f,
          description: package.description,
          display_order: package.display_order,
          recommended: package.recommended,
          active: package.active
        }
      end

      render_json_dump({
        success: true,
        created_count: created.length,
        packages: created
      })
    rescue => e
      render_json_error("添加示例套餐失败: #{e.message}", status: 500)
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
  end
end
