# 🚀 Coin 插件功能补充实施计划

## 📋 需求总结

### 1. **管理员加减积分时可选带上理由** ✅
- 管理员在调整积分时可以填写调整理由
- 用户界面在积分详情可以看到管理员调整的理由

### 2. **迁移文件需要补充** ✅
- 当前迁移文件只添加了 `invoice_url` 字段
- 需要确保 `invoice_url` 字段有默认值和验证

### 3. **管理员界面添加查询指定用户功能** ✅
- 管理员可以查询指定用户的当前积分数量
- 管理员可以查看该用户的积分详情

---

## 📦 实施计划

### 第一阶段：后端增强

#### 1.1 修改管理员控制器 - 添加查询用户功能
- **修改** `app/controllers/my_plugin_module/admin_controller.rb`
  - 添加 `get_user_balance` 方法：查询指定用户的积分余额
  - 添加 `get_user_transactions` 方法：查询指定用户的积分记录
  - 修改 `adjust_points` 方法：保存调整理由到交易记录的 `reason` 字段

#### 1.2 修改积分服务 - 添加查询用户方法
- **修改** `lib/my_plugin_module/coin_service.rb`
  - 添加 `get_user_balance_by_username` 方法：根据用户名查询积分
  - 添加 `get_user_transactions_by_username` 方法：根据用户名查询积分记录
  - 修改 `adjust_points!` 方法：保存调整理由

#### 1.3 更新路由配置
- **修改** `config/routes.rb`
  - 添加管理员查询用户路由：
    - `GET /admin/user_balance.json` - 查询用户余额
    - `GET /admin/user_transactions.json` - 查询用户积分记录

#### 1.4 补充迁移文件
- **修改** `db/migrate/20240101000004_add_invoice_url_to_coin_invoice_requests.rb`
  - 为 `invoice_url` 字段添加默认值 `nil`
  - 添加字段验证

---

## 🎨 第二阶段：前端增强

#### 2.1 修改管理员控制器 - 添加查询用户功能
- **修改** `assets/javascripts/discourse/controllers/coin-admin.js`
  - 添加 `queryUsername` 字段：查询用户名
  - 添加 `queryResult` 字段：查询结果
  - 添加 `showQueryResult` 字段：显示查询结果
  - 添加 `queryUserBalance` 方法：查询用户余额
  - 添加 `queryUserTransactions` 方法：查询用户积分记录

#### 2.2 修改管理员模板 - 添加查询用户界面
- **修改** `assets/javascripts/discourse/templates/coin-admin.hbs`
  - 在积分统计面板下方添加"查询用户"功能
  - 显示查询结果（用户余额和积分记录）
  - 使用 FontAwesome 图标

#### 2.3 修改用户积分模板 - 显示管理员调整理由
- **修改** `assets/javascripts/discourse/templates/coin.hbs`
  - 在积分记录中，如果是管理员调整类型，显示调整理由
  - 添加理由显示样式

#### 2.4 修改用户积分控制器 - 确保理由字段传递
- **修改** `assets/javascripts/discourse/controllers/coin.js`
  - 确保交易记录包含 `reason` 字段
  - 确保前端正确显示理由

#### 2.5 更新样式文件
- **修改** `assets/stylesheets/coin.scss`
  - 添加查询结果样式
  - 添加管理员调整理由显示样式

---

## 📁 最终文件结构

```
e:\code\
├── app/
│   └── controllers/
│       └── my_plugin_module/
│           ├── admin_controller.rb  # ✅ 修改（添加查询用户功能）
│           ├── coin_controller.rb  # ✅ 保留
│           └── invoice_controller.rb  # ✅ 保留
├── lib/
│   └── my_plugin_module/
│       ├── coin_service.rb  # ✅ 修改（添加查询用户方法）
│       └── invoice_service.rb  # ✅ 保留
├── config/
│   └── routes.rb  # ✅ 修改（添加查询用户路由）
├── db/
│   └── migrate/
│       └── 20240101000004_add_invoice_url_to_coin_invoice_requests.rb  # ✅ 修改（补充字段验证）
├── assets/
│   ├── javascripts/
│   │   └── discourse/
│   │       ├── controllers/
│   │       │   ├── coin.js  # ✅ 修改（确保理由字段传递）
│   │       │   ├── coin-invoice.js  # ✅ 保留
│   │       │   └── coin-admin.js  # ✅ 修改（添加查询用户功能）
│   │       └── templates/
│   │           ├── coin.hbs  # ✅ 修改（显示管理员调整理由）
│   │           ├── coin-invoice.hbs  # ✅ 保留
│   │           └── coin-admin.hbs  # ✅ 修改（添加查询用户界面）
│   └── stylesheets/
│       └── coin.scss  # ✅ 修改（添加查询结果样式）
└── plugin.rb  # ✅ 保留
```

---

## 🎯 关键功能点

### 1. 管理员调整积分时可选带上理由
- 后端：`adjust_points` 方法保存 `reason` 参数到交易记录
- 前端：管理员界面已有理由输入框
- 用户界面：在积分记录中显示管理员调整的理由

### 2. 管理员查询指定用户
- 后端：添加 `get_user_balance` 和 `get_user_transactions` 方法
- 前端：管理员界面添加查询用户表单
- 显示结果：用户余额和最近积分记录

### 3. 迁移文件补充
- 为 `invoice_url` 字段添加默认值和验证
- 确保数据库字段正确创建

---

## 📊 API 端点

### 新增管理员查询用户 API
- `GET /coin/admin/user_balance.json?username=xxx` - 查询用户余额
- `GET /coin/admin/user_transactions.json?username=xxx&limit=20` - 查询用户积分记录

### 修改的 API 端点
- `POST /coin/admin/adjust_points.json` - 添加 `reason` 参数（已有，确保保存）

---

## ✨ 技术亮点

1. **理由追踪**：管理员调整积分时可以填写理由，用户可以看到
2. **用户查询**：管理员可以快速查询指定用户的积分情况
3. **数据完整性**：确保所有调整都有理由记录
4. **用户体验**：用户可以看到完整的积分变动历史
5. **FontAwesome 图标**：保持统一的图标风格
6. **苹果设计**：保持优雅的界面风格

---

## 📝 实施步骤

1. 修改后端管理员控制器（添加查询用户方法）
2. 修改后端积分服务（添加查询用户方法）
3. 修改路由配置（添加查询用户路由）
4. 修改前端管理员控制器（添加查询用户功能）
5. 修改前端管理员模板（添加查询用户界面）
6. 修改前端用户积分模板（显示管理员调整理由）
7. 修改前端用户积分控制器（确保理由字段传递）
8. 修改样式文件（添加查询结果样式）
9. 补充迁移文件（添加字段验证）

预计修改 7 个文件，新建 0 个文件。