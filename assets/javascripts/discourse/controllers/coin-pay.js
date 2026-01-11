import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { service } from "@ember/service";

export default class CoinPayController extends Controller {
  @service router;
  @service siteSettings;
  @service currentUser;

  queryParams = ["payment"];
  @tracked payment = null;

  @tracked selectedPackageId = null;
  @tracked selectedPaymentType = "alipay";
  @tracked isLoading = false;
  @tracked showQrcodeModal = false;
  @tracked qrcodeUrl = "";
  @tracked currentOrderNo = "";
  @tracked pollingTimer = null;
  @tracked countdownTimer = null;
  @tracked remainingSeconds = 0;

  // 待支付订单提示
  @tracked showPendingAlert = false;

  // 自定义充值
  @tracked customAmount = "";
  @tracked isCustomMode = false;

  // 管理员套餐管理
  @tracked showAdminModal = false;
  @tracked adminPackages = [];
  @tracked isAdminLoading = false;
  @tracked editingPackage = null;
  @tracked showEditModal = false;

  // 管理员渠道管理
  @tracked showChannelModal = false;
  @tracked adminChannels = [];
  @tracked isChannelLoading = false;

  // 管理员折扣管理
  @tracked showDiscountModal = false;
  @tracked discountGroups = [];
  @tracked isDiscountLoading = false;
  @tracked editingGroup = null;
  @tracked showGroupEditModal = false;
  @tracked showGroupUsersModal = false;
  @tracked selectedGroupId = null;
  @tracked groupUsers = [];
  @tracked userSearchTerm = "";
  @tracked userSearchResults = [];
  @tracked isSearching = false;

  // 折扣组编辑表单
  @tracked editGroupName = "";
  @tracked editGroupRate = "";
  @tracked editGroupDescription = "";

  // 编辑表单
  @tracked editCoinAmount = "";
  @tracked editPrice = "";
  @tracked editDescription = "";
  @tracked editDisplayOrder = "";
  @tracked editRecommended = false;
  @tracked editActive = true;

  get isAdmin() {
    return this.currentUser?.admin;
  }

  get paymentSuccess() {
    return this.model?.paymentStatus === "success";
  }

  get paymentFailed() {
    return this.model?.paymentStatus === "failed" || this.model?.paymentStatus === "error";
  }

  get hasPendingOrder() {
    return this.model?.pendingOrder && this.remainingSeconds > 0;
  }

  get pendingOrder() {
    return this.model?.pendingOrder;
  }

  get formattedCountdown() {
    const mins = Math.floor(this.remainingSeconds / 60);
    const secs = this.remainingSeconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  }

  get selectedPackage() {
    if (this.isCustomMode) return null;
    if (!this.selectedPackageId) return null;
    return this.model?.packages?.find(p => p.id === this.selectedPackageId);
  }

  get totalAmount() {
    if (this.isCustomMode) {
      const amount = parseInt(this.customAmount) || 0;
      if (amount <= 0) return "0.00";
      // 自定义充值也享受折扣
      const discountRate = this.model?.discountRate || 100;
      return (amount * discountRate / 100).toFixed(2);
    }
    if (!this.selectedPackage) return "0.00";
    return this.selectedPackage.actual_price.toFixed(2);
  }

  get totalCoins() {
    if (this.isCustomMode) {
      return parseInt(this.customAmount) || 0;
    }
    return this.selectedPackage?.coin_amount || 0;
  }

  get payDisabled() {
    if (this.isLoading) return true;
    if (this.showPendingAlert) return true;
    if (!this.selectedPaymentType) return true;
    if (!this.model?.channels?.length) return true;
    if (this.isCustomMode) {
      const amount = parseInt(this.customAmount) || 0;
      return amount < 1 || amount > 10000;
    }
    return !this.selectedPackageId;
  }

  get paymentTypeName() {
    const names = {
      alipay: "支付宝",
      wxpay: "微信",
      wechat: "微信",
      paypal: "PayPal",
      qqpay: "QQ钱包",
      unionpay: "银联",
      bank: "银行卡",
      jdpay: "京东支付",
      usdt: "USDT",
      trc20: "USDT-TRC20",
      erc20: "USDT-ERC20"
    };
    return names[this.selectedPaymentType] || this.selectedPaymentType;
  }

  get customAmountError() {
    const amount = parseInt(this.customAmount) || 0;
    if (this.customAmount && amount < 1) return "最少充值1个";
    if (amount > 10000) return "单次最多10000个";
    return null;
  }

  @action
  goBack() {
    this.router.transitionTo("coin");
  }

  @action
  selectPackage(pkg) {
    this.selectedPackageId = pkg.id;
    this.isCustomMode = false;
    this.customAmount = "";
  }

  @action
  selectCustomMode() {
    this.isCustomMode = true;
    this.selectedPackageId = null;
  }

  @action
  updateCustomAmount(event) {
    const value = event.target.value.replace(/[^0-9]/g, '');
    this.customAmount = value;
    if (value) {
      this.isCustomMode = true;
      this.selectedPackageId = null;
    }
  }

  @action
  selectPaymentType(type) {
    this.selectedPaymentType = type;
  }

  @action
  async submitPayment() {
    if (this.isCustomMode) {
      await this.submitCustomPayment();
    } else {
      await this.submitPackagePayment();
    }
  }

  async submitPackagePayment() {
    if (!this.selectedPackageId) {
      alert("请选择充值套餐");
      return;
    }

    this.isLoading = true;

    try {
      const result = await ajax("/coin/pay/create_order.json", {
        type: "POST",
        data: {
          package_id: this.selectedPackageId,
          payment_type: this.selectedPaymentType,
          mode: "page"
        }
      });

      if (result.success && result.pay_url) {
        this.currentOrderNo = result.out_trade_no;
        window.location.href = result.pay_url;
      } else {
        alert("创建订单失败");
      }
    } catch (error) {
      console.error("创建订单失败:", error);
      alert("创建订单失败: " + (error.jqXHR?.responseJSON?.errors?.[0] || error.message));
    } finally {
      this.isLoading = false;
    }
  }

  async submitCustomPayment() {
    const amount = parseInt(this.customAmount) || 0;
    if (amount < 1 || amount > 10000) {
      alert("请输入有效的充值数量（1-10000）");
      return;
    }

    this.isLoading = true;

    try {
      const result = await ajax("/coin/pay/create_custom_order.json", {
        type: "POST",
        data: {
          coin_amount: amount,
          payment_type: this.selectedPaymentType,
          mode: "page"
        }
      });

      if (result.success && result.pay_url) {
        this.currentOrderNo = result.out_trade_no;
        window.location.href = result.pay_url;
      } else {
        alert("创建订单失败");
      }
    } catch (error) {
      console.error("创建订单失败:", error);
      alert("创建订单失败: " + (error.jqXHR?.responseJSON?.errors?.[0] || error.message));
    } finally {
      this.isLoading = false;
    }
  }

  @action
  closeQrcodeModal() {
    this.showQrcodeModal = false;
    this.qrcodeUrl = "";
    this.stopPolling();
  }

  @action
  stopPropagation(event) {
    event.stopPropagation();
  }

  startPolling() {
    this.stopPolling();
    this.pollingTimer = setInterval(() => this.checkOrderStatus(), 3000);
  }

  stopPolling() {
    if (this.pollingTimer) {
      clearInterval(this.pollingTimer);
      this.pollingTimer = null;
    }
  }

  async checkOrderStatus() {
    if (!this.currentOrderNo) return;

    try {
      const result = await ajax("/coin/pay/order_status.json", {
        data: { out_trade_no: this.currentOrderNo }
      });

      if (result.paid) {
        this.stopPolling();
        this.closeQrcodeModal();
        this.router.transitionTo("coin");
        alert(`支付成功！已充值 ${result.coin_amount} ${this.model.coinName}`);
      }
    } catch (error) {
      console.error("查询订单状态失败:", error);
    }
  }

  // ==================== 管理员功能 ====================

  @action
  async openAdminModal() {
    this.showAdminModal = true;
    await this.loadAdminPackages();
  }

  @action
  closeAdminModal() {
    this.showAdminModal = false;
    this.editingPackage = null;
    this.showEditModal = false;
  }

  @action
  async loadAdminPackages() {
    this.isAdminLoading = true;
    try {
      const result = await ajax("/coin/pay/admin/packages.json");
      this.adminPackages = result.packages || [];
    } catch (error) {
      console.error("加载套餐失败:", error);
      alert("加载套餐失败");
    } finally {
      this.isAdminLoading = false;
    }
  }

  @action
  openCreateModal() {
    this.editingPackage = null;
    this.editCoinAmount = "";
    this.editPrice = "";
    this.editDescription = "";
    this.editDisplayOrder = String(this.adminPackages.length + 1);
    this.editRecommended = false;
    this.editActive = true;
    this.showEditModal = true;
  }

  @action
  openEditModal(pkg) {
    this.editingPackage = pkg;
    this.editCoinAmount = String(pkg.coin_amount);
    this.editPrice = String(pkg.price);
    this.editDescription = pkg.description || "";
    this.editDisplayOrder = String(pkg.display_order);
    this.editRecommended = pkg.recommended;
    this.editActive = pkg.active;
    this.showEditModal = true;
  }

  @action
  closeEditModal() {
    this.showEditModal = false;
    this.editingPackage = null;
  }

  @action
  updateEditField(field, event) {
    this[field] = event.target.value;
  }

  @action
  toggleEditCheckbox(field) {
    this[field] = !this[field];
  }

  @action
  async savePackage() {
    const data = {
      coin_amount: parseInt(this.editCoinAmount) || 0,
      price: parseFloat(this.editPrice) || 0,
      description: this.editDescription,
      display_order: parseInt(this.editDisplayOrder) || 0,
      recommended: this.editRecommended,
      active: this.editActive
    };

    if (data.coin_amount < 1) {
      alert("硬币数量必须大于0");
      return;
    }
    if (data.price <= 0) {
      alert("价格必须大于0");
      return;
    }

    this.isAdminLoading = true;
    try {
      if (this.editingPackage) {
        await ajax(`/coin/pay/admin/packages/${this.editingPackage.id}.json`, {
          type: "PUT",
          data
        });
      } else {
        await ajax("/coin/pay/admin/packages.json", {
          type: "POST",
          data
        });
      }
      this.closeEditModal();
      await this.loadAdminPackages();
      // 刷新用户可见的套餐列表
      this.send('refreshModel');
    } catch (error) {
      console.error("保存套餐失败:", error);
      alert("保存套餐失败: " + (error.jqXHR?.responseJSON?.errors?.[0] || error.message));
    } finally {
      this.isAdminLoading = false;
    }
  }

  @action
  async deletePackage(pkg) {
    if (!confirm(`确定要删除套餐"${pkg.coin_amount}${this.model.coinName}"吗？`)) {
      return;
    }

    this.isAdminLoading = true;
    try {
      await ajax(`/coin/pay/admin/packages/${pkg.id}.json`, {
        type: "DELETE"
      });
      await this.loadAdminPackages();
      this.send('refreshModel');
    } catch (error) {
      console.error("删除套餐失败:", error);
      alert("删除套餐失败");
    } finally {
      this.isAdminLoading = false;
    }
  }

  @action
  async seedPackages() {
    if (!confirm("确定要添加示例套餐吗？（10/20/50/100）")) {
      return;
    }

    this.isAdminLoading = true;
    try {
      const result = await ajax("/coin/pay/admin/seed_packages.json", {
        type: "POST"
      });
      if (result.created_count > 0) {
        alert(`成功添加 ${result.created_count} 个示例套餐`);
      } else {
        alert("示例套餐已存在，无需重复添加");
      }
      await this.loadAdminPackages();
      this.send('refreshModel');
    } catch (error) {
      console.error("添加示例套餐失败:", error);
      alert("添加示例套餐失败");
    } finally {
      this.isAdminLoading = false;
    }
  }

  @action
  async togglePackageActive(pkg) {
    this.isAdminLoading = true;
    try {
      await ajax(`/coin/pay/admin/packages/${pkg.id}.json`, {
        type: "PUT",
        data: { active: !pkg.active }
      });
      await this.loadAdminPackages();
      this.send('refreshModel');
    } catch (error) {
      console.error("更新套餐状态失败:", error);
      alert("更新失败");
    } finally {
      this.isAdminLoading = false;
    }
  }

  // ==================== 渠道管理功能 ====================

  @action
  async openChannelModal() {
    this.showChannelModal = true;
    await this.loadAdminChannels();
  }

  @action
  closeChannelModal() {
    this.showChannelModal = false;
  }

  @action
  async loadAdminChannels() {
    this.isChannelLoading = true;
    try {
      const result = await ajax("/coin/pay/admin/channels.json");
      this.adminChannels = result.channels || [];
    } catch (error) {
      console.error("加载渠道失败:", error);
      alert("加载渠道失败");
    } finally {
      this.isChannelLoading = false;
    }
  }

  @action
  async toggleChannelEnabled(channel) {
    this.isChannelLoading = true;
    try {
      await ajax(`/coin/pay/admin/channels/${channel.id}.json`, {
        type: "PUT",
        data: { enabled: !channel.enabled }
      });
      await this.loadAdminChannels();
      this.send('refreshModel');
    } catch (error) {
      console.error("更新渠道状态失败:", error);
      alert("更新失败");
    } finally {
      this.isChannelLoading = false;
    }
  }

  @action
  async seedChannels() {
    if (!confirm("确定要重置默认渠道吗？（支付宝/微信/PayPal）")) {
      return;
    }

    this.isChannelLoading = true;
    try {
      const result = await ajax("/coin/pay/admin/seed_channels.json", {
        type: "POST"
      });
      if (result.created_count > 0) {
        alert(`成功添加 ${result.created_count} 个渠道`);
      } else {
        alert("默认渠道已存在");
      }
      await this.loadAdminChannels();
      this.send('refreshModel');
    } catch (error) {
      console.error("添加渠道失败:", error);
      alert("添加渠道失败");
    } finally {
      this.isChannelLoading = false;
    }
  }

  // ==================== 折扣管理功能 ====================

  @action
  async openDiscountModal() {
    this.showDiscountModal = true;
    await this.loadDiscountGroups();
  }

  @action
  closeDiscountModal() {
    this.showDiscountModal = false;
    this.editingGroup = null;
    this.showGroupEditModal = false;
    this.showGroupUsersModal = false;
  }

  @action
  async loadDiscountGroups() {
    this.isDiscountLoading = true;
    try {
      const result = await ajax("/coin/pay/admin/discount_groups.json");
      this.discountGroups = result.groups || [];
    } catch (error) {
      console.error("加载折扣组失败:", error);
      alert("加载折扣组失败");
    } finally {
      this.isDiscountLoading = false;
    }
  }

  @action
  openCreateGroupModal() {
    this.editingGroup = null;
    this.editGroupName = "";
    this.editGroupRate = "90";
    this.editGroupDescription = "";
    this.showGroupEditModal = true;
  }

  @action
  openEditGroupModal(group) {
    this.editingGroup = group;
    this.editGroupName = group.name;
    this.editGroupRate = String(group.discount_rate);
    this.editGroupDescription = group.description || "";
    this.showGroupEditModal = true;
  }

  @action
  closeGroupEditModal() {
    this.showGroupEditModal = false;
    this.editingGroup = null;
  }

  @action
  updateGroupField(field, event) {
    this[field] = event.target.value;
  }

  @action
  async saveDiscountGroup() {
    const rate = parseInt(this.editGroupRate) || 0;
    if (!this.editGroupName.trim()) {
      alert("请输入折扣组名称");
      return;
    }
    if (rate < 1 || rate > 100) {
      alert("折扣率必须在1-100之间");
      return;
    }

    const data = {
      name: this.editGroupName.trim(),
      discount_rate: rate,
      description: this.editGroupDescription
    };

    this.isDiscountLoading = true;
    try {
      if (this.editingGroup) {
        await ajax(`/coin/pay/admin/discount_groups/${this.editingGroup.id}.json`, {
          type: "PUT",
          data
        });
      } else {
        await ajax("/coin/pay/admin/discount_groups.json", {
          type: "POST",
          data
        });
      }
      this.closeGroupEditModal();
      await this.loadDiscountGroups();
      this.send('refreshModel');
    } catch (error) {
      console.error("保存折扣组失败:", error);
      alert("保存失败: " + (error.jqXHR?.responseJSON?.errors?.[0] || error.message));
    } finally {
      this.isDiscountLoading = false;
    }
  }

  @action
  async deleteDiscountGroup(group) {
    if (!confirm(`确定要删除折扣组"${group.name}"吗？该组内的用户将失去折扣。`)) {
      return;
    }

    this.isDiscountLoading = true;
    try {
      await ajax(`/coin/pay/admin/discount_groups/${group.id}.json`, {
        type: "DELETE"
      });
      await this.loadDiscountGroups();
      this.send('refreshModel');
    } catch (error) {
      console.error("删除折扣组失败:", error);
      alert("删除失败");
    } finally {
      this.isDiscountLoading = false;
    }
  }

  @action
  async openGroupUsersModal(group) {
    this.selectedGroupId = group.id;
    this.showGroupUsersModal = true;
    this.userSearchTerm = "";
    this.userSearchResults = [];
    await this.loadGroupUsers(group.id);
  }

  @action
  closeGroupUsersModal() {
    this.showGroupUsersModal = false;
    this.selectedGroupId = null;
    this.groupUsers = [];
    this.userSearchTerm = "";
    this.userSearchResults = [];
  }

  @action
  async loadGroupUsers(groupId) {
    this.isDiscountLoading = true;
    try {
      const result = await ajax(`/coin/pay/admin/discount_groups/${groupId}/users.json`);
      this.groupUsers = result.users || [];
    } catch (error) {
      console.error("加载用户列表失败:", error);
      alert("加载用户列表失败");
    } finally {
      this.isDiscountLoading = false;
    }
  }

  @action
  updateUserSearchTerm(event) {
    this.userSearchTerm = event.target.value;
  }

  @action
  async searchUsers() {
    if (!this.userSearchTerm.trim()) {
      this.userSearchResults = [];
      return;
    }

    this.isSearching = true;
    try {
      const result = await ajax("/coin/pay/admin/search_users.json", {
        data: { term: this.userSearchTerm.trim() }
      });
      // 过滤掉已在组内的用户
      const existingIds = this.groupUsers.map(u => u.id);
      this.userSearchResults = (result.users || []).filter(u => !existingIds.includes(u.id));
    } catch (error) {
      console.error("搜索用户失败:", error);
    } finally {
      this.isSearching = false;
    }
  }

  @action
  async addUserToGroup(user) {
    this.isDiscountLoading = true;
    try {
      await ajax("/coin/pay/admin/discount_users.json", {
        type: "POST",
        data: {
          username: user.username,
          group_id: this.selectedGroupId
        }
      });
      this.groupUsers = [...this.groupUsers, user];
      this.userSearchResults = this.userSearchResults.filter(u => u.id !== user.id);
      await this.loadDiscountGroups();
    } catch (error) {
      console.error("添加用户失败:", error);
      alert("添加失败: " + (error.jqXHR?.responseJSON?.errors?.[0] || error.message));
    } finally {
      this.isDiscountLoading = false;
    }
  }

  @action
  async removeUserFromGroup(user) {
    if (!confirm(`确定要将用户"${user.username}"从该折扣组移除吗？`)) {
      return;
    }

    this.isDiscountLoading = true;
    try {
      await ajax("/coin/pay/admin/discount_users.json", {
        type: "DELETE",
        data: {
          user_id: user.id,
          group_id: this.selectedGroupId
        }
      });
      this.groupUsers = this.groupUsers.filter(u => u.id !== user.id);
      await this.loadDiscountGroups();
    } catch (error) {
      console.error("移除用户失败:", error);
      alert("移除失败");
    } finally {
      this.isDiscountLoading = false;
    }
  }

  get selectedGroup() {
    return this.discountGroups.find(g => g.id === this.selectedGroupId);
  }

  willDestroy() {
    super.willDestroy();
    this.stopPolling();
    this.stopCountdown();
  }

  // 初始化待支付订单倒计时
  initPendingOrder() {
    if (this.model?.pendingOrder) {
      this.remainingSeconds = this.model.pendingOrder.remaining_seconds || 0;
      this.showPendingAlert = this.remainingSeconds > 0;
      if (this.remainingSeconds > 0) {
        this.startCountdown();
      }
    }
  }

  startCountdown() {
    this.stopCountdown();
    this.countdownTimer = setInterval(() => {
      if (this.remainingSeconds > 0) {
        this.remainingSeconds--;
      } else {
        this.stopCountdown();
        this.showPendingAlert = false;
        // 刷新页面数据
        this.send('refreshModel');
      }
    }, 1000);
  }

  stopCountdown() {
    if (this.countdownTimer) {
      clearInterval(this.countdownTimer);
      this.countdownTimer = null;
    }
  }

  @action
  dismissPendingAlert() {
    this.showPendingAlert = false;
  }
}
