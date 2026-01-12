# frozen_string_literal: true

module ::MyPluginModule
  class CoinController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    def index
      render "default/empty"
    rescue => e
      Rails.logger.error "[积分] 页面错误: #{e.message}"
      render plain: "Error: #{e.message}", status: 500
    end

    def balance
      ensure_logged_in

      begin
        balance = MyPluginModule::CoinService.get_user_balance(current_user.id)

        render_json_dump({
          success: true,
          user_id: current_user.id,
          username: current_user.username,
          balance: balance,
          coin_name: SiteSetting.coin_name || "硬币"
        })
      rescue => e
        Rails.logger.error "[积分] 获取余额失败: #{e.message}"
        render_json_error("获取余额失败", status: 500)
      end
    end

    def transactions
      ensure_logged_in

      begin
        limit = (params[:limit] || 20).to_i
        transactions = MyPluginModule::CoinService.get_user_transactions(current_user.id, limit: limit)

        render_json_dump({
          success: true,
          transactions: transactions,
          total: transactions.length
        })
      rescue => e
        Rails.logger.error "[积分] 获取交易记录失败: #{e.message}"
        render_json_error("获取交易记录失败", status: 500)
      end
    end

    def admin_adjust
      ensure_logged_in
      ensure_admin

      begin
        target_username = params[:username]
        amount = params[:amount].to_i
        reason = params[:reason] || "管理员调整"

        unless target_username.present?
          render_json_error("用户名不能为空", status: 400)
          return
        end

        unless amount != 0
          render_json_error("调整数量不能为0", status: 400)
          return
        end

        target_user = User.find_by(username: target_username)
        unless target_user
          render_json_error("用户不存在", status: 404)
          return
        end

        result = MyPluginModule::CoinService.adjust_points!(
          current_user,
          target_user,
          amount,
          reason: reason
        )

        render_json_dump({
          success: true,
          message: "积分调整成功",
          result: result
        })
      rescue => e
        Rails.logger.error "[积分] 管理员调整失败: #{e.message}"
        render_json_error(e.message, status: 500)
      end
    end

    private

    def ensure_admin
      raise Discourse::InvalidAccess unless current_user&.admin?
    end
  end
end