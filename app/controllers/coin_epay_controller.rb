# frozen_string_literal: true

# 易支付回调控制器 - 直接继承 ApplicationController
# 这个控制器不在 MyPluginModule 命名空间内，以便直接被 Discourse 主路由访问
class CoinEpayController < ::ApplicationController
  skip_before_action :check_xhr
  skip_before_action :verify_authenticity_token
  skip_before_action :redirect_to_login_if_required

  # GET/POST /coin_epay_notify - 异步回调
  def notify
    epay = ::MyPluginModule::EpayService.new
    callback_params = params.to_unsafe_h.except(:controller, :action)

    # 验证签名
    unless epay.verify_callback(callback_params)
      Rails.logger.warn "[Coin] Epay notify 签名验证失败: #{callback_params}"
      render plain: 'fail'
      return
    end

    # 检查交易状态
    unless params[:trade_status] == 'TRADE_SUCCESS'
      Rails.logger.info "[Coin] Epay notify 交易状态非成功: #{params[:trade_status]}"
      render plain: 'success'
      return
    end

    # 处理支付成功
    result = ::MyPluginModule::PaymentService.process_payment_success(
      params[:out_trade_no],
      params[:trade_no],
      params[:money]
    )

    Rails.logger.info "[Coin] Epay notify 处理结果: #{result}"
    render plain: result[:success] ? 'success' : 'fail'
  end

  # GET /coin_epay_return - 同步回调（用户浏览器跳转）
  def return_page
    Rails.logger.info "[Coin] Epay return 收到回调: #{params.to_unsafe_h}"
    
    epay = ::MyPluginModule::EpayService.new
    callback_params = params.to_unsafe_h.except(:controller, :action)

    if epay.verify_callback(callback_params) && params[:trade_status] == 'TRADE_SUCCESS'
      # 处理支付成功
      ::MyPluginModule::PaymentService.process_payment_success(
        params[:out_trade_no],
        params[:trade_no],
        params[:money]
      )
      Rails.logger.info "[Coin] Epay return 支付成功，重定向到 /coin/pay?payment=success"
      redirect_to "/coin/pay?payment=success"
    else
      Rails.logger.warn "[Coin] Epay return 验证失败或状态非成功"
      redirect_to "/coin/pay?payment=failed"
    end
  end
end
