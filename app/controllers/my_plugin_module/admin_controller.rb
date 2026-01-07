# frozen_string_literal: true

module ::MyPluginModule
  class AdminController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    def index
      render "default/empty"
    rescue => e
      Rails.logger.error "[管理员] 页面错误: #{e.message}"
      render plain: "Error: #{e.message}", status: 500
    end

    def adjust_points
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
        Rails.logger.error "[管理员] 调整积分失败: #{e.message}"
        render_json_error(e.message, status: 500)
      end
    end

    def get_user_balance
      ensure_logged_in
      ensure_admin

      begin
        target_username = params[:username]

        unless target_username.present?
          render_json_error("用户名不能为空", status: 400)
          return
        end

        target_user = User.find_by(username: target_username)
        unless target_user
          render_json_error("用户不存在", status: 404)
          return
        end

        balance = MyPluginModule::CoinService.get_user_balance(target_user.id)

        render_json_dump({
          success: true,
          username: target_user.username,
          balance: balance
        })
      rescue => e
        Rails.logger.error "[管理员] 获取用户余额失败: #{e.message}"
        render_json_error("获取用户余额失败", status: 500)
      end
    end

    def get_user_transactions
      ensure_logged_in
      ensure_admin

      begin
        target_username = params[:username]
        limit = (params[:limit] || 20).to_i

        unless target_username.present?
          render_json_error("用户名不能为空", status: 400)
          return
        end

        target_user = User.find_by(username: target_username)
        unless target_user
          render_json_error("用户不存在", status: 404)
          return
        end

        transactions = MyPluginModule::CoinService.get_user_transactions(target_user.id, limit: limit)

        render_json_dump({
          success: true,
          username: target_user.username,
          transactions: transactions,
          total: transactions.length
        })
      rescue => e
        Rails.logger.error "[管理员] 获取用户积分记录失败: #{e.message}"
        render_json_error("获取用户积分记录失败", status: 500)
      end
    end

    def recent_transactions
      ensure_logged_in
      ensure_admin

      begin
        limit = (params[:limit] || 20).to_i
        transactions = MyPluginModule::CoinService.get_recent_recharges(limit: limit)

        render_json_dump({
          success: true,
          transactions: transactions,
          total: transactions.length
        })
      rescue => e
        Rails.logger.error "[管理员] 获取最近充值记录失败: #{e.message}"
        render_json_error("获取最近充值记录失败", status: 500)
      end
    end

    def user_statistics
      ensure_logged_in
      ensure_admin

      begin
        statistics = MyPluginModule::CoinService.get_statistics

        render_json_dump({
          success: true,
          statistics: statistics
        })
      rescue => e
        Rails.logger.error "[管理员] 获取用户统计失败: #{e.message}"
        render_json_error("获取用户统计失败", status: 500)
      end
    end

    def pending_invoices
      ensure_logged_in
      ensure_admin

      begin
        limit = (params[:limit] || 50).to_i
        invoices = MyPluginModule::InvoiceService.get_all_invoice_requests(limit: limit, status: "pending")

        render_json_dump({
          success: true,
          invoices: invoices,
          total: invoices.length
        })
      rescue => e
        Rails.logger.error "[管理员] 获取待处理发票失败: #{e.message}"
        render_json_error("获取待处理发票失败", status: 500)
      end
    end

    def process_invoice
      ensure_logged_in
      ensure_admin

      begin
        invoice_id = params[:id].to_i
        invoice_url = params[:invoice_url]

        unless invoice_id > 0
          render_json_error("发票ID无效", status: 400)
          return
        end

        unless invoice_url.present?
          render_json_error("发票URL不能为空", status: 400)
          return
        end

        invoice = MyPluginModule::InvoiceService.process_invoice(
          invoice_id,
          invoice_url
        )

        render_json_dump({
          success: true,
          message: "发票处理成功",
          invoice: {
            id: invoice.id,
            status: invoice.status,
            invoice_url: invoice.invoice_url,
            updated_at: invoice.updated_at.iso8601
          }
        })
      rescue => e
        Rails.logger.error "[管理员] 处理发票失败: #{e.message}"
        render_json_error(e.message, status: 500)
      end
    end
  end
end