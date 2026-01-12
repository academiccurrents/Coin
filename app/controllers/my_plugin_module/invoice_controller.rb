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

        unless amount > 0
          render_json_error("申请金额必须大于0", status: 400)
          return
        end

        # 基础创建参数
        create_params = {
          user_id: current_user.id,
          amount: amount,
          reason: reason,
          status: 'pending'
        }

        # 如果新列存在，添加额外字段
        if column_exists?(:invoice_type)
          invoice_type = params[:invoice_type] || 'personal'
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

          create_params[:invoice_type] = invoice_type
          create_params[:invoice_title] = invoice_title
          create_params[:id_number] = invoice_type == 'personal' ? id_number : nil
          create_params[:tax_number] = invoice_type == 'company' ? tax_number : nil
        end

        if column_exists?(:out_trade_no)
          out_trade_no = params[:out_trade_no]
          # 检查订单号是否已申请过发票
          if out_trade_no.present?
            existing = CoinInvoiceRequest.find_by(out_trade_no: out_trade_no)
            if existing
              render_json_error("该订单已申请过发票", status: 400)
              return
            end
            create_params[:out_trade_no] = out_trade_no
          end
        end

        invoice = CoinInvoiceRequest.create!(create_params)

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

    # POST /coin/invoice/create_from_transaction - 从交易记录创建发票申请（旧版兼容）
    def create_from_transaction
      ensure_logged_in

      begin
        transaction_id = params[:transaction_id].to_i

        unless transaction_id > 0
          render_json_error("交易ID无效", status: 400)
          return
        end

        # 查找交易记录
        transaction = CoinTransaction.find_by(id: transaction_id, user_id: current_user.id)
        unless transaction
          render_json_error("交易记录不存在", status: 404)
          return
        end

        # 检查是否已申请过发票
        existing = CoinInvoiceRequest.find_by(admin_note: "关联交易ID: #{transaction_id}")
        if existing
          render_json_error("该交易已申请过发票", status: 400)
          return
        end

        # 创建发票申请
        invoice = CoinInvoiceRequest.create!(
          user_id: current_user.id,
          amount: transaction.amount,
          status: 'pending',
          reason: "充值发票申请",
          admin_note: "关联交易ID: #{transaction_id}"
        )

        Rails.logger.info "[发票] 用户 #{current_user.id} 从交易 #{transaction_id} 创建发票申请"

        render_json_dump({
          success: true,
          message: "发票申请提交成功",
          invoice: serialize_invoice(invoice)
        })
      rescue => e
        Rails.logger.error "[发票] 从交易创建申请失败: #{e.message}"
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

        # 如果新列不存在，返回错误
        unless column_exists?(:invoice_type)
          render_json_error("请先运行数据库迁移", status: 500)
          return
        end

        invoice_type = params[:invoice_type] || safe_get(invoice, :invoice_type) || 'personal'
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

    # POST /coin/invoice/resubmit/:id - 用户重新申请被拒绝的发票
    def resubmit
      ensure_logged_in

      begin
        invoice_id = params[:id].to_i
        invoice = CoinInvoiceRequest.find_by(id: invoice_id, user_id: current_user.id)

        unless invoice
          render_json_error("发票申请不存在", status: 404)
          return
        end

        # 如果新列不存在，返回错误
        unless column_exists?(:resubmit_count)
          render_json_error("请先运行数据库迁移", status: 500)
          return
        end

        unless invoice.can_resubmit?
          if invoice.rejected?
            render_json_error("重新申请次数已用完，无法再次申请", status: 400)
          else
            render_json_error("只有被拒绝的发票才能重新申请", status: 400)
          end
          return
        end

        invoice_type = params[:invoice_type] || safe_get(invoice, :invoice_type) || 'personal'
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

        # 更新发票信息并重置状态为待处理
        invoice.update!(
          status: 'pending',
          invoice_type: invoice_type,
          invoice_title: invoice_title,
          id_number: invoice_type == 'personal' ? id_number : nil,
          tax_number: invoice_type == 'company' ? tax_number : nil,
          resubmit_count: (invoice.resubmit_count || 0) + 1,
          reject_reason: nil  # 清除之前的拒绝理由
        )

        Rails.logger.info "[发票] 用户 #{current_user.id} 重新申请发票 #{invoice_id}，第 #{invoice.resubmit_count} 次"

        render_json_dump({
          success: true,
          message: "重新申请成功，请等待审核",
          invoice: serialize_invoice(invoice)
        })
      rescue => e
        Rails.logger.error "[发票] 重新申请失败: #{e.message}"
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
        # 获取已支付的订单
        orders_scope = CoinPaymentOrder.where(user_id: current_user.id, status: 'paid')
        
        # 如果 out_trade_no 列存在，排除已申请发票的订单
        if column_exists?(:out_trade_no)
          orders_scope = orders_scope.where.not(out_trade_no: CoinInvoiceRequest.where(user_id: current_user.id).select(:out_trade_no))
        end
        
        orders = orders_scope.order(created_at: :desc).limit(50)

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

        update_attrs = { status: new_status, updated_at: Time.current }
        update_attrs[:admin_note] = admin_note if admin_note.present?
        update_attrs[:reject_reason] = reject_reason if new_status == 'rejected' && reject_reason.present? && column_exists?(:reject_reason)
        update_attrs[:invoice_url] = invoice_url if new_status == 'completed' && invoice_url.present?

        # 使用 update_columns 跳过验证，因为只是更新状态
        invoice.update_columns(update_attrs)
        invoice.reload

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

    # 检查列是否存在
    def column_exists?(column_name)
      CoinInvoiceRequest.column_names.include?(column_name.to_s)
    rescue
      false
    end

    # 安全获取属性值
    def safe_get(invoice, attr)
      invoice.respond_to?(attr) ? invoice.send(attr) : nil
    rescue
      nil
    end

    def serialize_invoice(invoice)
      result = {
        id: invoice.id,
        amount: invoice.amount,
        status: invoice.status,
        status_text: status_text(invoice.status),
        reason: invoice.reason,
        invoice_url: safe_get(invoice, :invoice_url),
        editable: invoice.editable?,
        created_at: invoice.created_at.iso8601,
        updated_at: invoice.updated_at.iso8601
      }

      # 安全添加新字段
      if column_exists?(:invoice_type)
        result[:invoice_type] = safe_get(invoice, :invoice_type) || 'personal'
        result[:invoice_type_text] = invoice.personal? ? '个人' : '企业'
        result[:invoice_title] = safe_get(invoice, :invoice_title)
        result[:id_number] = invoice.personal? ? mask_id_number(safe_get(invoice, :id_number)) : nil
        result[:tax_number] = invoice.company? ? safe_get(invoice, :tax_number) : nil
      end

      if column_exists?(:out_trade_no)
        result[:out_trade_no] = safe_get(invoice, :out_trade_no)
      end

      if column_exists?(:reject_reason)
        result[:reject_reason] = safe_get(invoice, :reject_reason)
      end

      if column_exists?(:resubmit_count)
        result[:resubmit_count] = safe_get(invoice, :resubmit_count) || 0
        result[:can_resubmit] = invoice.can_resubmit?
        result[:remaining_resubmit_count] = invoice.remaining_resubmit_count
      else
        result[:resubmit_count] = 0
        result[:can_resubmit] = false
        result[:remaining_resubmit_count] = 0
      end

      result
    end

    def serialize_invoice_for_admin(invoice)
      user = User.find_by(id: invoice.user_id)
      result = {
        id: invoice.id,
        user_id: invoice.user_id,
        username: user&.username,
        avatar_url: user&.avatar_template&.gsub('{size}', '45'),
        amount: invoice.amount,
        status: invoice.status,
        status_text: status_text(invoice.status),
        reason: invoice.reason,
        admin_note: safe_get(invoice, :admin_note),
        invoice_url: safe_get(invoice, :invoice_url),
        created_at: invoice.created_at.iso8601,
        updated_at: invoice.updated_at.iso8601
      }

      # 安全添加新字段
      if column_exists?(:invoice_type)
        result[:invoice_type] = safe_get(invoice, :invoice_type) || 'personal'
        result[:invoice_type_text] = invoice.personal? ? '个人' : '企业'
        result[:invoice_title] = safe_get(invoice, :invoice_title)
        result[:id_number] = safe_get(invoice, :id_number)  # 管理员可以看到完整信息
        result[:tax_number] = safe_get(invoice, :tax_number)
      end

      if column_exists?(:out_trade_no)
        result[:out_trade_no] = safe_get(invoice, :out_trade_no)
      end

      if column_exists?(:reject_reason)
        result[:reject_reason] = safe_get(invoice, :reject_reason)
      end

      result
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
