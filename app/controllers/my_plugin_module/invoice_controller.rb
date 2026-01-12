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

    # POST /coin/invoice/create - 创建发票申请
    def create
      ensure_logged_in

      begin
        amount = params[:amount].to_i
        reason = params[:reason] || "发票申请"
        invoice_type = params[:invoice_type] || 'personal'
        invoice_title = params[:invoice_title]
        id_number = params[:id_number]
        tax_number = params[:tax_number]
        out_trade_no = params[:out_trade_no]

        unless amount > 0
          render_json_error("申请金额必须大于0", status: 400)
          return
        end

        unless %w[personal company].include?(invoice_type)
          render_json_error("发票类型无效", status: 400)
          return
        end

        # 验证必填字段
        if invoice_type == 'personal'
          unless invoice_title.present? && id_number.present?
            render_json_error("个人发票需要填写姓名和身份证号码", status: 400)
            return
          end
        else
          unless invoice_title.present? && tax_number.present?
            render_json_error("企业发票需要填写公司名称和纳税人识别号", status: 400)
            return
          end
        end

        # 检查订单号是否已申请过发票
        if out_trade_no.present?
          existing = CoinInvoiceRequest.find_by(out_trade_no: out_trade_no)
          if existing
            render_json_error("该订单已申请过发票", status: 400)
            return
          end
        end

        invoice = CoinInvoiceRequest.create!(
          user_id: current_user.id,
          amount: amount,
          reason: reason,
          status: 'pending',
          invoice_type: invoice_type,
          invoice_title: invoice_title,
          id_number: invoice_type == 'personal' ? id_number : nil,
          tax_number: invoice_type == 'company' ? tax_number : nil,
          out_trade_no: out_trade_no
        )

        render_json_dump({
          success: true,
          message: "发票申请提交成功",
          invoice: serialize_invoice(invoice)
        })
      rescue => e
        Rails.logger.error "[发票] 创建申请失败: #{e.message}"
        render_json_error(e.message, status: 500)
      end
    end

    # PUT /coin/invoice/update/:id - 用户更新待处理的发票信息
    def update
      ensure_logged_in

      begin
        invoice_id = params[:id].to_i
        invoice = CoinInvoiceRequest.find_by(id: invoice_id, user_id: current_user.id)

        unless invoice
          render_json_error("发票申请不存在", status: 404)
          return
        end

        unless invoice.editable?
          render_json_error("只能修改待处理状态的发票申请", status: 400)
          return
        end

        invoice_type = params[:invoice_type] || invoice.invoice_type
        invoice_title = params[:invoice_title]
        id_number = params[:id_number]
        tax_number = params[:tax_number]

        unless %w[personal company].include?(invoice_type)
          render_json_error("发票类型无效", status: 400)
          return
        end

        # 验证必填字段
        if invoice_type == 'personal'
          unless invoice_title.present? && id_number.present?
            render_json_error("个人发票需要填写姓名和身份证号码", status: 400)
            return
          end
        else
          unless invoice_title.present? && tax_number.present?
            render_json_error("企业发票需要填写公司名称和纳税人识别号", status: 400)
            return
          end
        end

        invoice.update!(
          invoice_type: invoice_type,
          invoice_title: invoice_title,
          id_number: invoice_type == 'personal' ? id_number : nil,
          tax_number: invoice_type == 'company' ? tax_number : nil
        )

        render_json_dump({
          success: true,
          message: "发票信息更新成功",
          invoice: serialize_invoice(invoice)
        })
      rescue => e
        Rails.logger.error "[发票] 更新申请失败: #{e.message}"
        render_json_error(e.message, status: 500)
      end
    end

    # GET /coin/invoice/list - 获取用户发票列表
    def list
      ensure_logged_in

      begin
        limit = (params[:limit] || 20).to_i
        invoices = CoinInvoiceRequest.by_user(current_user.id).recent.limit(limit)

        render_json_dump({
          success: true,
          invoices: invoices.map { |inv| serialize_invoice(inv) },
          total: invoices.length
        })
      rescue => e
        Rails.logger.error "[发票] 获取申请列表失败: #{e.message}"
        render_json_error("获取申请列表失败", status: 500)
      end
    end

    # GET /coin/invoice/eligible_orders - 获取可开票的订单列表
    def eligible_orders
      ensure_logged_in

      begin
        # 获取已支付的订单，排除已申请发票的
        orders = CoinPaymentOrder.where(user_id: current_user.id, status: 'paid')
                                 .where.not(out_trade_no: CoinInvoiceRequest.where(user_id: current_user.id).select(:out_trade_no))
                                 .order(created_at: :desc)
                                 .limit(50)

        render_json_dump({
          success: true,
          orders: orders.map { |order| serialize_order_for_invoice(order) }
        })
      rescue => e
        Rails.logger.error "[发票] 获取可开票订单失败: #{e.message}"
        render_json_error("获取可开票订单失败", status: 500)
      end
    end

    # POST /coin/invoice/update_status - 管理员更新发票状态
    def update_status
      ensure_logged_in
      ensure_admin

      begin
        invoice_id = params[:id].to_i
        new_status = params[:status]
        admin_note = params[:admin_note]
        reject_reason = params[:reject_reason]
        invoice_url = params[:invoice_url]

        unless invoice_id > 0
          render_json_error("发票ID无效", status: 400)
          return
        end

        unless CoinInvoiceRequest::STATUSES.include?(new_status)
          render_json_error("状态无效，可选值：#{CoinInvoiceRequest::STATUSES.join(', ')}", status: 400)
          return
        end

        invoice = CoinInvoiceRequest.find_by(id: invoice_id)
        unless invoice
          render_json_error("发票申请不存在", status: 404)
          return
        end

        update_attrs = { status: new_status }
        update_attrs[:admin_note] = admin_note if admin_note.present?
        update_attrs[:reject_reason] = reject_reason if new_status == 'rejected' && reject_reason.present?
        update_attrs[:invoice_url] = invoice_url if new_status == 'completed' && invoice_url.present?

        invoice.update!(update_attrs)

        render_json_dump({
          success: true,
          message: "发票状态更新成功",
          invoice: serialize_invoice_for_admin(invoice)
        })
      rescue => e
        Rails.logger.error "[发票] 更新状态失败: #{e.message}"
        render_json_error(e.message, status: 500)
      end
    end

    private

    def ensure_admin
      raise Discourse::InvalidAccess unless current_user&.admin?
    end

    def serialize_invoice(invoice)
      {
        id: invoice.id,
        amount: invoice.amount,
        status: invoice.status,
        status_text: status_text(invoice.status),
        reason: invoice.reason,
        invoice_type: invoice.invoice_type,
        invoice_type_text: invoice.personal? ? '个人' : '企业',
        invoice_title: invoice.invoice_title,
        id_number: invoice.personal? ? mask_id_number(invoice.id_number) : nil,
        tax_number: invoice.company? ? invoice.tax_number : nil,
        out_trade_no: invoice.out_trade_no,
        invoice_url: invoice.invoice_url,
        reject_reason: invoice.reject_reason,
        editable: invoice.editable?,
        created_at: invoice.created_at.iso8601,
        updated_at: invoice.updated_at.iso8601
      }
    end

    def serialize_invoice_for_admin(invoice)
      user = User.find_by(id: invoice.user_id)
      {
        id: invoice.id,
        user_id: invoice.user_id,
        username: user&.username,
        avatar_url: user&.avatar_template&.gsub('{size}', '45'),
        amount: invoice.amount,
        status: invoice.status,
        status_text: status_text(invoice.status),
        reason: invoice.reason,
        invoice_type: invoice.invoice_type,
        invoice_type_text: invoice.personal? ? '个人' : '企业',
        invoice_title: invoice.invoice_title,
        id_number: invoice.id_number,  # 管理员可以看到完整信息
        tax_number: invoice.tax_number,
        out_trade_no: invoice.out_trade_no,
        invoice_url: invoice.invoice_url,
        admin_note: invoice.admin_note,
        reject_reason: invoice.reject_reason,
        created_at: invoice.created_at.iso8601,
        updated_at: invoice.updated_at.iso8601
      }
    end

    def serialize_order_for_invoice(order)
      {
        id: order.id,
        out_trade_no: order.out_trade_no,
        actual_price: order.actual_price.to_f,
        coin_amount: order.coin_amount,
        payment_type: order.payment_type,
        created_at: order.created_at.iso8601
      }
    end

    def status_text(status)
      case status
      when 'pending' then '待处理'
      when 'completed' then '已完成'
      when 'rejected' then '已拒绝'
      else status
      end
    end

    # 脱敏身份证号码，只显示前3位和后4位
    def mask_id_number(id_number)
      return nil unless id_number.present?
      return id_number if id_number.length <= 7
      "#{id_number[0..2]}#{'*' * (id_number.length - 7)}#{id_number[-4..-1]}"
    end
  end
end
