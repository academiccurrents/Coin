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

    def self.adjust_points!(acting_user, target_user, amount, reason: "管理员调整")
      ActiveRecord::Base.transaction do
        balance = CoinUserBalance.get_or_create(target_user.id)
        old_balance = balance.balance
        new_balance = old_balance + amount

        if new_balance < 0
          raise StandardError, "积分不足，当前余额: #{old_balance}，尝试扣除: #{-amount}"
        end

        balance.update!(balance: new_balance)

        CoinTransaction.create!(
          user_id: target_user.id,
          amount: amount,
          balance_after: new_balance,
          reason: reason,
          transaction_type: "admin_adjust"
        )

        Rails.logger.info "[积分] 用户 #{target_user.username} 积分调整: #{amount > 0 ? '+' : ''}#{amount}，原因: #{reason}"

        {
          user_id: target_user.id,
          username: target_user.username,
          old_balance: old_balance,
          new_balance: new_balance,
          amount: amount,
          reason: reason
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

    def self.get_user_transactions_by_username(user_id, limit: 20)
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
      CoinTransaction
        .by_type("recharge")
        .recent
        .limit(limit)
        .joins(:user)
        .select("coin_transactions.*, users.username, users.avatar_template")
        .map do |t|
          {
            id: t.id,
            user_id: t.user_id,
            username: t.user.username,
            avatar_url: t.user.avatar_template_url.gsub("{size}", "45"),
            amount: t.amount,
            balance_after: t.balance_after,
            reason: t.reason,
            created_at: t.created_at.iso8601
          }
        end
    end

    def self.get_statistics
      total_users = CoinUserBalance.count
      total_balance = CoinUserBalance.sum(:balance)
      average_balance = total_users > 0 ? (total_balance.to_f / total_users).round(2) : 0

      {
        total_users: total_users,
        total_balance: total_balance,
        average_balance: average_balance
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
        .joins(:user)
        .select("coin_user_balances.*, users.username, users.avatar_template")
        .order("coin_user_balances.balance DESC")
        .limit(limit)
        .map do |b|
          {
            user_id: b.user_id,
            username: b.user.username,
            avatar_url: b.user.avatar_template_url.gsub("{size}", "45"),
            balance: b.balance
          }
        end
    end
  end
end