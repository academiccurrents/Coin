# frozen_string_literal: true

module ::MyPluginModule
  class DiscountService
    # 获取用户的折扣率（返回最低折扣率，即最大优惠）
    def self.get_user_discount(user_id)
      group_ids = CoinDiscountGroupUser.by_user(user_id).pluck(:discount_group_id)
      return 100 if group_ids.empty?

      # 返回最低折扣率（最大优惠）
      min_rate = CoinDiscountGroup.where(id: group_ids).minimum(:discount_rate)
      min_rate || 100
    end

    # 计算折扣后的价格（低于0.01元不打折）
    def self.calculate_discounted_price(original_price, discount_rate)
      discounted = (original_price.to_f * discount_rate / 100.0).round(2)
      # 如果折扣后价格低于0.01元，则不打折，返回原价
      discounted < 0.01 ? original_price.to_f.round(2) : discounted
    end

    # 获取用户所属的所有折扣组
    def self.get_user_groups(user_id)
      group_ids = CoinDiscountGroupUser.by_user(user_id).pluck(:discount_group_id)
      CoinDiscountGroup.where(id: group_ids).ordered
    end

    # 添加用户到折扣组
    def self.add_user_to_group(user_id, group_id)
      CoinDiscountGroupUser.find_or_create_by!(
        user_id: user_id,
        discount_group_id: group_id
      ) do |record|
        record.created_at = Time.current
      end
    end

    # 从折扣组移除用户
    def self.remove_user_from_group(user_id, group_id)
      CoinDiscountGroupUser.where(
        user_id: user_id,
        discount_group_id: group_id
      ).destroy_all
    end

    # 批量添加用户到折扣组
    def self.add_users_to_group(user_ids, group_id)
      user_ids.each do |user_id|
        add_user_to_group(user_id, group_id)
      rescue ActiveRecord::RecordInvalid
        # 忽略已存在的记录
        next
      end
    end

    # 批量从折扣组移除用户
    def self.remove_users_from_group(user_ids, group_id)
      CoinDiscountGroupUser.where(
        user_id: user_ids,
        discount_group_id: group_id
      ).destroy_all
    end

    # 获取折扣组的所有用户
    def self.get_group_users(group_id, limit: 100)
      user_ids = CoinDiscountGroupUser.by_group(group_id).limit(limit).pluck(:user_id)
      User.where(id: user_ids).map do |user|
        {
          id: user.id,
          username: user.username,
          avatar_url: user.avatar_template.gsub('{size}', '45')
        }
      end
    end

    # 检查用户是否在折扣组中
    def self.user_in_group?(user_id, group_id)
      CoinDiscountGroupUser.exists?(user_id: user_id, discount_group_id: group_id)
    end
  end
end
