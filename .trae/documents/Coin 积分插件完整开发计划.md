# 🪙 Coin 积分插件开发计划

## 📦 第一阶段：基础配置和数据库设计

### 1.1 修改插件配置
- 更新 `plugin.rb`：插件名称为 discourse-coin，作者 pandacc，添加 GitHub 链接
- 修复 Engine 挂载问题（在 after_initialize 中挂载到 /coin）
- 更新 `config/settings.yml`：添加 coin_enabled 和积分代币名称配置

### 1.2 创建数据库迁移文件（符合宝典规范）
- `db/migrate/20240101000001_create_coin_user_balances.rb`：用户积分余额表
- `db/migrate/20240101000002_create_coin_transactions.rb`：积分交易记录表
- `db/migrate/20240101000003_create_coin_invoice_requests.rb`：发票申请表
- 使用幂等创建、唯一索引命名、兼容 ActiveRecord::Migration[6.0]

### 1.3 创建数据模型
- `app/models/my_plugin_module/coin_user_balance.rb`：用户积分余额模型
- `app/models/my_plugin_module/coin_transaction.rb`：积分交易记录模型
- `app/models/my_plugin_module/coin_invoice_request.rb`：发票申请模型

## 🎯 第二阶段：后端服务层

### 2.1 创建服务类
- `lib/my_plugin_module/coin_service.rb`：核心积分服务
  - `adjust_points!`：调整用户积分（管理员加减）
  - `get_user_balance`：获取用户积分余额
  - `get_user_transactions`：获取用户积分记录
  - `record_transaction`：记录积分变动
- `lib/my_plugin_module/invoice_service.rb`：发票服务
  - `create_invoice_request`：创建发票申请
  - `get_invoice_requests`：获取发票申请列表
  - `update_invoice_status`：更新发票状态

### 2.2 创建控制器
- `app/controllers/my_plugin_module/coin_controller.rb`：积分控制器
  - `index`：用户积分主页
  - `balance`：获取用户积分
  - `transactions`：获取积分记录
  - `admin_adjust`：管理员调整积分
- `app/controllers/my_plugin_module/invoice_controller.rb`：发票控制器
  - `index`：发票申请页面
  - `create`：创建发票申请
  - `list`：获取发票列表
  - `update_status`：更新发票状态（管理员）

## 🎨 第三阶段：前端用户界面（苹果设计）

### 3.1 创建前端路由
- `assets/javascripts/discourse/coin-route-map.js`：路由映射
- `assets/javascripts/discourse/routes/coin.js`：路由处理器
- `assets/javascripts/discourse/routes/coin-invoice.js`：发票路由

### 3.2 创建前端控制器
- `assets/javascripts/discourse/controllers/coin.js`：积分页面控制器
- `assets/javascripts/discourse/controllers/coin-invoice.js`：发票页面控制器

### 3.3 创建前端模板（苹果设计风格）
- `assets/javascripts/discourse/templates/coin.hbs`：积分主页
  - 积分余额卡片（大数字显示）
  - 积分记录列表（时间轴样式）
  - 申请发票按钮
- `assets/javascripts/discourse/templates/coin-invoice.hbs`：发票申请页面
  - 发票申请表单
  - 发票申请列表（状态标签：待开票/已开票）

### 3.4 创建样式文件
- `assets/stylesheets/coin.scss`：苹果设计风格
  - 使用 SF Pro 字体风格
  - 圆角卡片设计（border-radius: 12px）
  - 柔和阴影（box-shadow）
  - 渐变背景
  - 响应式布局

## 🚀 第四阶段：测试和优化

### 4.1 功能测试
- 测试积分查询功能
- 测试积分记录显示
- 测试发票申请流程
- 测试管理员调整积分

### 4.2 界面优化
- 确保苹果设计风格一致性
- 优化响应式布局
- 添加加载状态和错误处理

## 📁 最终文件结构

```
e:\code\
├── plugin.rb                                    # ✅ 修改
├── config/
│   ├── routes.rb                                # ✅ 修改
│   └── settings.yml                             # ✅ 修改
├── db/
│   └── migrate/
│       ├── 20240101000001_create_coin_user_balances.rb    # ✅ 新建
│       ├── 20240101000002_create_coin_transactions.rb    # ✅ 新建
│       └── 20240101000003_create_coin_invoice_requests.rb # ✅ 新建
├── app/
│   ├── models/
│   │   └── my_plugin_module/
│   │       ├── coin_user_balance.rb              # ✅ 新建
│   │       ├── coin_transaction.rb               # ✅ 新建
│   │       └── coin_invoice_request.rb           # ✅ 新建
│   └── controllers/
│       └── my_plugin_module/
│           ├── coin_controller.rb                # ✅ 新建
│           └── invoice_controller.rb             # ✅ 新建
├── lib/
│   └── my_plugin_module/
│       ├── engine.rb                            # ✅ 保留
│       ├── coin_service.rb                       # ✅ 新建
│       └── invoice_service.rb                    # ✅ 新建
└── assets/
    ├── javascripts/
    │   └── discourse/
    │       ├── coin-route-map.js                 # ✅ 新建
    │       ├── routes/
    │       │   ├── coin.js                       # ✅ 新建
    │       │   └── coin-invoice.js               # ✅ 新建
    │       ├── controllers/
    │       │   ├── coin.js                       # ✅ 新建
    │       │   └── coin-invoice.js               # ✅ 新建
    │       ├── templates/
    │       │   ├── coin.hbs                      # ✅ 新建
    │       │   └── coin-invoice.hbs              # ✅ 新建
    │       └── initializers/
    │           └── coin-plugin.js                 # ✅ 新建
    └── stylesheets/
        └── coin.scss                             # ✅ 新建
```

## ✨ 设计亮点

### 苹果设计风格特点：
1. **简洁优雅**：大量留白，清晰的视觉层次
2. **圆角卡片**：12px 圆角，柔和阴影
3. **大数字显示**：积分余额使用大号字体突出显示
4. **渐变背景**：使用柔和的渐变色
5. **流畅动画**：按钮悬停、点击效果
6. **响应式布局**：适配移动端和桌面端

### 用户体验优化：
- 实时积分查询
- 清晰的积分记录时间轴
- 直观的发票申请流程
- 友好的错误提示

## 📊 数据库表设计

### coin_user_balances（用户积分余额）
- user_id（用户ID，唯一）
- balance（积分余额）
- updated_at（更新时间）

### coin_transactions（积分交易记录）
- user_id（用户ID）
- amount（变动数量，正数为增加，负数为减少）
- balance_after（变动后余额）
- reason（变动原因）
- transaction_type（交易类型：recharge/admin_adjust/consumption）
- created_at（创建时间）

### coin_invoice_requests（发票申请）
- user_id（用户ID）
- amount（开票金额）
- status（状态：pending/completed）
- reason（开票原因）
- admin_note（管理员备注）
- created_at（创建时间）
- updated_at（更新时间）