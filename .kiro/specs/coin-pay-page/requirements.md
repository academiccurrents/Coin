# Coin Plugin - 充值支付系统需求规格

## 概述

Discourse 论坛的硬币/积分管理插件，包含充值支付、发票申请和 Epay 支付集成功能。采用 Rails Engine 架构 + Ember Glimmer Components。

---

## 用户故事

### US-1: 用户充值

**作为** 论坛用户  
**我希望** 能够通过多种支付方式充值硬币  
**以便** 在论坛中使用硬币进行消费

**验收标准:**
- [ ] 用户可以在 `/coin/pay` 页面查看当前余额
- [ ] 用户可以选择预设套餐或自定义充值金额（1-10000）
- [ ] 用户可以选择已启用的支付渠道（支付宝/微信/PayPal等）
- [ ] 点击支付后跳转到第三方支付页面
- [ ] 支付成功后自动到账并显示成功提示
- [ ] 支付失败显示错误提示

---

### US-2: 待支付订单管理

**作为** 论坛用户  
**我希望** 能够继续支付未完成的订单  
**以便** 不需要重新创建订单

**验收标准:**
- [ ] 用户有待支付订单时显示提示横幅
- [ ] 显示订单金额、硬币数量和剩余时间倒计时
- [ ] 提供"继续支付"按钮跳转到支付页面
- [ ] 订单超时（2分钟）后自动过期
- [ ] 用户可以关闭待支付提示

---

### US-3: 折扣优惠

**作为** 特权用户  
**我希望** 充值时能享受折扣优惠  
**以便** 以更低价格获得硬币

**验收标准:**
- [ ] 用户所属折扣组的折扣率自动应用
- [ ] 页面显示折扣标识和折扣后价格
- [ ] 套餐显示原价（划线）和折扣价
- [ ] 自定义充值也享受折扣
- [ ] 折扣后价格低于0.01元时不打折

---

### US-4: 管理员套餐管理

**作为** 管理员  
**我希望** 能够管理充值套餐  
**以便** 灵活配置充值选项

**验收标准:**
- [ ] 管理员可以查看所有套餐列表
- [ ] 管理员可以添加新套餐（硬币数量、价格、描述、排序、推荐标记）
- [ ] 管理员可以编辑现有套餐
- [ ] 管理员可以删除套餐
- [ ] 管理员可以上架/下架套餐
- [ ] 提供一键添加示例套餐功能

---

### US-5: 管理员渠道管理

**作为** 管理员  
**我希望** 能够管理支付渠道  
**以便** 控制用户可用的支付方式

**验收标准:**
- [ ] 管理员可以查看所有支付渠道
- [ ] 管理员可以启用/禁用支付渠道
- [ ] 未启用任何渠道时显示"管理员未开启支付"提示
- [ ] 提供一键添加默认渠道功能（支付宝/微信/PayPal）

---

### US-6: 管理员折扣管理

**作为** 管理员  
**我希望** 能够管理折扣组和用户  
**以便** 为特定用户提供优惠

**验收标准:**
- [ ] 管理员可以创建折扣组（名称、折扣率1-100、描述）
- [ ] 管理员可以编辑折扣组
- [ ] 管理员可以删除折扣组
- [ ] 管理员可以查看折扣组内的用户列表
- [ ] 管理员可以搜索并添加用户到折扣组
- [ ] 管理员可以从折扣组移除用户
- [ ] 显示每个折扣组的用户数量

---

### US-7: 支付回调处理

**作为** 系统  
**我希望** 能够正确处理支付回调  
**以便** 自动完成订单和到账

**验收标准:**
- [ ] 支持 GET 和 POST 方式的异步回调（notify）
- [ ] 支持同步回调（return）并重定向到支付结果页
- [ ] 验证回调签名（MD5算法）
- [ ] 验证交易状态为 TRADE_SUCCESS
- [ ] 防止重复处理同一订单
- [ ] 回调接口跳过登录和CSRF验证

---

## 技术规格

### 数据模型

#### CoinPaymentOrder（支付订单）
- `user_id`: 用户ID
- `out_trade_no`: 商户订单号
- `trade_no`: 第三方交易号
- `coin_amount`: 硬币数量
- `original_price`: 原价
- `actual_price`: 实付金额
- `payment_type`: 支付方式
- `status`: 状态（pending/paid/expired/failed）
- `pay_url`: 支付链接
- `paid_at`: 支付时间

#### CoinPaymentChannel（支付渠道）
- `channel_type`: 渠道类型（alipay/wxpay/paypal）
- `name`: 显示名称
- `icon`: 图标标识
- `enabled`: 是否启用
- `display_order`: 排序

#### CoinDiscountGroup（折扣组）
- `name`: 组名称
- `discount_rate`: 折扣率（1-100）
- `description`: 描述

#### CoinDiscountGroupUser（折扣组用户关联）
- `discount_group_id`: 折扣组ID
- `user_id`: 用户ID

---

### API 端点

#### 用户端点
| 方法 | 路径 | 描述 |
|------|------|------|
| GET | `/coin/pay` | 充值页面 |
| GET | `/coin/pay/packages` | 获取套餐列表 |
| GET | `/coin/pay/channels` | 获取支付渠道 |
| POST | `/coin/pay/create_order` | 创建套餐订单 |
| POST | `/coin/pay/create_custom_order` | 创建自定义订单 |
| GET | `/coin/pay/order_status` | 查询订单状态 |
| GET | `/coin/pay/pending_order` | 获取待支付订单 |
| GET | `/coin/pay/orders` | 获取订单列表 |

#### 回调端点
| 方法 | 路径 | 描述 |
|------|------|------|
| GET/POST | `/coin/pay/notify` | 异步回调 |
| GET | `/coin/pay/return` | 同步回调 |

#### 管理员端点
| 方法 | 路径 | 描述 |
|------|------|------|
| GET | `/coin/pay/admin/packages` | 获取套餐列表 |
| POST | `/coin/pay/admin/packages` | 创建套餐 |
| PUT | `/coin/pay/admin/packages/:id` | 更新套餐 |
| DELETE | `/coin/pay/admin/packages/:id` | 删除套餐 |
| POST | `/coin/pay/admin/seed_packages` | 添加示例套餐 |
| GET | `/coin/pay/admin/channels` | 获取渠道列表 |
| PUT | `/coin/pay/admin/channels/:id` | 更新渠道 |
| POST | `/coin/pay/admin/seed_channels` | 添加默认渠道 |
| GET | `/coin/pay/admin/discount_groups` | 获取折扣组 |
| POST | `/coin/pay/admin/discount_groups` | 创建折扣组 |
| PUT | `/coin/pay/admin/discount_groups/:id` | 更新折扣组 |
| DELETE | `/coin/pay/admin/discount_groups/:id` | 删除折扣组 |
| GET | `/coin/pay/admin/discount_groups/:id/users` | 获取组用户 |
| POST | `/coin/pay/admin/discount_users` | 添加用户到组 |
| DELETE | `/coin/pay/admin/discount_users` | 从组移除用户 |
| GET | `/coin/pay/admin/search_users` | 搜索用户 |

---

### Epay 集成规格

#### 签名算法
1. 参数按字母顺序排序
2. 拼接为 `key1=value1&key2=value2` 格式
3. 直接追加商户密钥（不加 `&key=`）
4. MD5 哈希生成签名

#### 配置项
- `coin_epay_api_url`: API地址
- `coin_epay_pid`: 商户ID
- `coin_epay_key`: 商户密钥
- `coin_name`: 硬币名称

---

### 前端组件

#### 路由
- `coin-pay`: 充值页面路由

#### 控制器状态
- 套餐选择状态
- 支付方式选择状态
- 自定义充值模式
- 待支付订单倒计时
- 管理员模态框状态

#### UI 组件
- 余额卡片（含折扣标识）
- 套餐选择网格
- 自定义充值输入
- 支付方式选择
- 支付按钮区域
- 待支付订单提示横幅
- 管理员套餐管理模态框
- 管理员渠道管理模态框
- 管理员折扣管理模态框

---

## 设计约束

1. 使用内联 SVG 图标，不使用 `{{d-icon}}` 组件
2. 仅使用 Font Awesome Free 图标
3. 背景色使用 Discourse CSS 变量
4. Rails 8 枚举语法：`enum :status, {...}`
5. 插件名称为 `coin`
6. 支付页脚不超出插件页面范围
7. 订单超时时间为 2 分钟
