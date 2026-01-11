# frozen_string_literal: true

module ::MyPluginModule
  class InvoiceController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    def index
      render "default/empty"
    rescue => e
      Rails.logger.error "[发票] 页面错误: #{e.message}"
      render plain: "Error: #{e.message}", status: 500
    end

    def create
      ensure_logged_in

      begin
        amount = params[:amount].to_i
        reason = params[:reason] || "发票申请"

        unless amount > 0
          render_json_error("申请金额必须大于0", status: 400)
          return
        end

        invoice = MyPluginModule::InvoiceService.create_invoice_request(
          current_user.id,
          amount,
          reason
        )

        render_json_dump({
          success: true,
          message: "发票申请提交成功",
          invoice: {
            id: invoice.id,
            amount: invoice.amount,
            status: invoice.status,
            reason: invoice.reason,
            created_at: invoice.created_at.iso8601
          }
        })
      rescue => e
        Rails.logger.error "[发票] 创建申请失败: #{e.message}"
        render_json_error(e.message, status: 500)
      end
    end

    def create_from_transaction
      ensure_logged_in

      begin
        transaction_id = params[:transaction_id].to_i

        unless transaction_id > 0
          render_json_error("交易ID无效", status: 400)
          return
        end

        # 从交易记录中获取信息
        transaction = CoinTransaction.find_by(id: transaction_id, user_id: current_user.id)
        
        unless transaction
          render_json_error("交易记录不存在或无权访问", status: 404)
          return
        end

        unless transaction.transaction_type == "recharge"
          render_json_error("只有充值记录可以申请发票", status: 400)
          return
        end

        unless transaction.amount > 0
          render_json_error("交易金额必须大于0", status: 400)
          return
        end

        # 检查是否已经申请过发票
        existing_invoice = CoinInvoiceRequest.find_by(
          user_id: current_user.id,
          admin_note: "关联交易ID: #{transaction_id}"
        )
        
        if existing_invoice
          render_json_error("该交易记录已申请过发票", status: 400)
          return
        end

        invoice = MyPluginModule::InvoiceService.create_invoice_from_transaction(
          current_user.id,
          transaction_id,
          transaction.amount,
          transaction.reason || "充值发票申请"
        )

        render_json_dump({
          success: true,
          message: "发票申请提交成功",
          invoice: {
            id: invoice.id,
            amount: invoice.amount,
            status: invoice.status,
            reason: invoice.reason,
            created_at: invoice.created_at.iso8601
          }
        })
      rescue => e
        Rails.logger.error "[发票] 从交易创建申请失败: #{e.message}"
        render_json_error(e.message, status: 500)
      end
    end

    def list
      ensure_logged_in

      begin
        limit = (params[:limit] || 20).to_i
        invoices = MyPluginModule::InvoiceService.get_invoice_requests(current_user.id, limit: limit)

        render_json_dump({
          success: true,
          invoices: invoices,
          total: invoices.length
        })
      rescue => e
        Rails.logger.error "[发票] 获取申请列表失败: #{e.message}"
        render_json_error("获取申请列表失败", status: 500)
      end
    end

    def update_status
      ensure_logged_in
      ensure_admin

      begin
        invoice_id = params[:id].to_i
        new_status = params[:status]
        admin_note = params[:admin_note]

        unless invoice_id > 0
          render_json_error("发票ID无效", status: 400)
          return
        end

        unless new_status.present?
          render_json_error("状态不能为空", status: 400)
          return
        end

        invoice = MyPluginModule::InvoiceService.update_invoice_status(
          invoice_id,
          new_status,
          admin_note: admin_note
        )

        render_json_dump({
          success: true,
          message: "发票状态更新成功",
          invoice: {
            id: invoice.id,
            status: invoice.status,
            admin_note: invoice.admin_note,
            updated_at: invoice.updated_at.iso8601
          }
        })
      rescue => e
        Rails.logger.error "[发票] 更新状态失败: #{e.message}"
        render_json_error(e.message, status: 500)
      end
    end
  end
end