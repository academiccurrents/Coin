# frozen_string_literal: true

module ::MyPluginModule
  class InvoiceService
    # 检查列是否存在的辅助方法
    def self.column_exists?(column_name)
      CoinInvoiceRequest.column_names.include?(column_name.to_s)
    rescue
      false
    end

    def self.create_invoice_request(user_id, amount, reason)
      ActiveRecord::Base.transaction do
        balance = CoinService.get_user_balance(user_id)

        if amount > balance
          raise StandardError, "积分不足，当前余额: #{balance}，申请金额: #{amount}"
        end

        invoice = CoinInvoiceRequest.create!(
          user_id: user_id,
          amount: amount,
          status: "pending",
          reason: reason
        )

        Rails.logger.info "[发票] 用户ID #{user_id} 创建发票申请: #{amount} 积分，原因: #{reason}"

        invoice
      end
    end

    def self.create_invoice_from_transaction(user_id, transaction_id, amount, reason)
      ActiveRecord::Base.transaction do
        invoice = CoinInvoiceRequest.create!(
          user_id: user_id,
          amount: amount,
          status: "pending",
          reason: reason,
          admin_note: "关联交易ID: #{transaction_id}"
        )

        Rails.logger.info "[发票] 用户ID #{user_id} 从交易 #{transaction_id} 创建发票申请: #{amount} 积分"

        invoice
      end
    end

    def self.get_invoice_requests(user_id, limit: 20)
      CoinInvoiceRequest
        .by_user(user_id)
        .recent
        .limit(limit)
        .map do |invoice|
          serialize_invoice_basic(invoice)
        end
    end

    def self.get_all_invoice_requests(limit: 50, status: nil)
      scope = CoinInvoiceRequest.includes(:user).recent

      scope = scope.by_status(status) if status.present?

      scope
        .limit(limit)
        .map do |invoice|
          next nil unless invoice.user
          serialize_invoice_for_admin(invoice)
        end.compact
    end

    def self.get_rejected_invoices(limit: 20, offset: 0)
      scope = CoinInvoiceRequest.includes(:user).by_status("rejected").recent

      total = scope.count
      invoices = scope.offset(offset).limit(limit).map do |invoice|
        next nil unless invoice.user
        serialize_invoice_for_admin(invoice)
      end.compact

      {
        invoices: invoices,
        total: total,
        has_more: (offset + limit) < total
      }
    end

    def self.process_invoice(invoice_id, invoice_url)
      invoice = CoinInvoiceRequest.find_by(id: invoice_id)

      unless invoice
        raise StandardError, "发票申请不存在"
      end

      unless invoice.pending?
        raise StandardError, "该发票申请已处理"
      end

      unless invoice_url.present?
        raise StandardError, "发票URL不能为空"
      end

      ActiveRecord::Base.transaction do
        invoice.update!(
          status: "completed",
          invoice_url: invoice_url
        )

        Rails.logger.info "[发票] 发票申请 #{invoice_id} 已处理，发票URL: #{invoice_url}"

        invoice
      end
    end

    def self.update_invoice_status(invoice_id, new_status, admin_note: nil)
      invoice = CoinInvoiceRequest.find_by(id: invoice_id)

      unless invoice
        raise StandardError, "发票申请不存在"
      end

      unless CoinInvoiceRequest::STATUSES.include?(new_status)
        raise StandardError, "无效的状态: #{new_status}"
      end

      ActiveRecord::Base.transaction do
        invoice.update!(
          status: new_status,
          admin_note: admin_note
        )

        Rails.logger.info "[发票] 发票申请 #{invoice_id} 状态更新为: #{new_status}，备注: #{admin_note}"

        invoice
      end
    end

    def self.get_completed_invoices(limit: 20, offset: 0)
      scope = CoinInvoiceRequest.includes(:user).by_status("completed").recent

      total = scope.count
      invoices = scope.offset(offset).limit(limit).map do |invoice|
        next nil unless invoice.user
        serialize_invoice_for_admin(invoice)
      end.compact

      {
        invoices: invoices,
        total: total,
        has_more: (offset + limit) < total
      }
    end

    def self.status_text(status)
      case status
      when 'pending' then '待处理'
      when 'completed' then '已完成'
      when 'rejected' then '已拒绝'
      else status
      end
    end

    def self.update_invoice_url(invoice_id, new_url)
      invoice = CoinInvoiceRequest.find_by(id: invoice_id)

      unless invoice
        raise StandardError, "发票申请不存在"
      end

      unless invoice.completed?
        raise StandardError, "只能修改已完成的发票URL"
      end

      unless new_url.present?
        raise StandardError, "发票URL不能为空"
      end

      ActiveRecord::Base.transaction do
        invoice.update!(invoice_url: new_url)
        Rails.logger.info "[发票] 发票 #{invoice_id} URL已更新为: #{new_url}"
        invoice
      end
    end

    private

    # 基础序列化（用户端）
    def self.serialize_invoice_basic(invoice)
      result = {
        id: invoice.id,
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

      result[:editable] = invoice.editable?

      result
    end

    # 管理员序列化
    def self.serialize_invoice_for_admin(invoice)
      result = {
        id: invoice.id,
        user_id: invoice.user_id,
        username: invoice.user&.username,
        avatar_url: invoice.user&.avatar_template&.gsub('{size}', '45'),
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

    # 安全获取属性值
    def self.safe_get(invoice, attr)
      invoice.respond_to?(attr) ? invoice.send(attr) : nil
    rescue
      nil
    end

    # 脱敏身份证号码
    def self.mask_id_number(id_number)
      return nil unless id_number.present?
      return id_number if id_number.length <= 7
      "#{id_number[0..2]}#{'*' * (id_number.length - 7)}#{id_number[-4..-1]}"
    end
  end
end
