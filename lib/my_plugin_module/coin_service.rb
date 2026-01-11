# frozen_string_literal: true

module ::MyPluginModule
  class CoinService
    def self.get_user_balance(user_id)
      balance = CoinUserBalance.get_or_create(user_id)
      balance.balance
    end

    def self.get_user_balance_by_username(username)
      user = User.find_by(username: username)
      return nil unless user
      get_user_balance(user.id)
    end

    def self.adjust_points!(acting_user, target_user, amount, reason: "管理员调整", mark_as_recharge: false)
      ActiveRecord::Base.transaction do
        balance = CoinUserBalance.get_or_create(target_user.id)
        old_balance = balance.balance
        new_balance = old_balance + amount

        if new_balance < 0
          raise StandardError, "积分不足，当前余额: #{old_balance}，尝试扣除: #{-amount}"
        end

        balance.update!(balance: new_balance)

        # 如果标记为充值，则使用 recharge 类型，否则使用 admin_adjust
        transaction_type = mark_as_recharge ? "recharge" : "admin_adjust"

        CoinTransaction.create!(
          user_id: target_user.id,
          amount: amount,
          balance_after: new_balance,
          reason: reason,
          transaction_type: transaction_type
        )

        Rails.logger.info "[积分] 用户 #{target_user.username} 积分调整: #{amount > 0 ? '+' : ''}#{amount}，原因: #{reason}，类型: #{transaction_type}"

        {
          user_id: target_user.id,
          username: target_user.username,
          old_balance: old_balance,
          new_balance: new_balance,
          amount: amount,
          reason: reason,
          transaction_type: transaction_type
        }
      end
    end

    def self.get_user_transactions(user_id, limit: 20)
      CoinTransaction
        .by_user(user_id)
        .recent
        .limit(limit)
        .map do |t|
          {
            id: t.id,
            amount: t.amount,
            balance_after: t.balance_after,
            reason: t.reason,
            transaction_type: t.transaction_type,
            created_at: t.created_at.iso8601
          }
        end
    end

    def self.get_recent_recharges(limit: 20)
      # 使用 includes 预加载 user 关联，避免 N+1 查询
      transactions = CoinTransaction
        .includes(:user)
        .by_type("recharge")
        .recent
        .limit(limit)

      transactions.map do |t|
        next nil unless t.user
        {
          id: t.id,
          user_id: t.user_id,
          username: t.user.username,
          amount: t.amount,
          balance_after: t.balance_after,
          reason: t.reason,
          created_at: t.created_at.iso8601
        }
      end.compact
    end

    def self.get_statistics
      total_users = CoinUserBalance.count
      total_balance = CoinUserBalance.sum(:balance)
      total_recharge = CoinTransaction.where(transaction_type: "recharge").where("amount > 0").sum(:amount)
      pending_invoices_count = CoinInvoiceRequest.by_status("pending").count

      {
        total_users: total_users,
        total_balance: total_balance,
        total_recharge: total_recharge,
        pending_invoices_count: pending_invoices_count
      }
    end

    def self.record_transaction(user_id, amount, reason, transaction_type)
      ActiveRecord::Base.transaction do
        balance = CoinUserBalance.get_or_create(user_id)
        old_balance = balance.balance
        new_balance = old_balance + amount

        if new_balance < 0
          raise StandardError, "积分不足，当前余额: #{old_balance}，尝试扣除: #{-amount}"
        end

        balance.update!(balance: new_balance)

        CoinTransaction.create!(
          user_id: user_id,
          amount: amount,
          balance_after: new_balance,
          reason: reason,
          transaction_type: transaction_type
        )

        Rails.logger.info "[积分] 用户ID #{user_id} 积分变动: #{amount > 0 ? '+' : ''}#{amount}，类型: #{transaction_type}，原因: #{reason}"

        new_balance
      end
    end

    def self.get_all_users_balance(limit: 50)
      CoinUserBalance
        .includes(:user)
        .order(balance: :desc)
        .limit(limit)
        .map do |b|
          next nil unless b.user
          {
            user_id: b.user_id,
            username: b.user.username,
            balance: b.balance
          }
        end.compact
    end
  end
end
