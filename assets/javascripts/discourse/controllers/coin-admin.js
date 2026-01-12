import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { service } from "@ember/service";

export default class CoinAdminController extends Controller {
  @service router;
  @service currentUser;
  
  @tracked isLoading = false;
  @tracked showSuccessMessage = false;
  @tracked successMessage = "";
  @tracked showProcessInvoiceModal = false;
  @tracked selectedInvoiceId = null;
  @tracked invoiceUrl = "";
  @tracked adjustUsername = "";
  @tracked adjustAmount = "";
  @tracked adjustReason = "";
  @tracked markAsRecharge = false;
  @tracked queryUsername = "";
  @tracked queryResult = null;
  @tracked showQueryResult = false;
  
  // 已处理发票相关
  @tracked completedInvoicesPage = 0;
  @tracked completedInvoicesList = [];
  @tracked hasMoreCompletedInvoices = false;
  @tracked isLoadingMore = false;
  @tracked showEditInvoiceModal = false;
  @tracked editingInvoice = null;
  @tracked editInvoiceUrl = "";
  
  // 拒绝发票相关
  @tracked showRejectInvoiceModal = false;
  @tracked rejectInvoiceId = null;
  @tracked rejectReason = "";
  
  // 查看发票详情
  @tracked showInvoiceDetailModal = false;
  @tracked selectedInvoiceDetail = null;

  get pendingInvoices() {
    return this.model?.pendingInvoices || [];
  }

  get recentTransactions() {
    return this.model?.recentTransactions || [];
  }

  get statistics() {
    return this.model?.statistics || {};
  }

  get completedInvoices() {
    // 如果已加载更多，使用本地列表；否则使用model数据
    if (this.completedInvoicesList.length > 0) {
      return this.completedInvoicesList;
    }
    return this.model?.completedInvoices || [];
  }

  get showLoadMoreCompletedInvoices() {
    // 如果已经加载过更多，使用本地状态；否则使用model数据
    if (this.completedInvoicesPage > 0) {
      return this.hasMoreCompletedInvoices;
    }
    return this.model?.hasMoreCompletedInvoices || false;
  }

  get transactionTypeLabels() {
    return {
      recharge: { label: "充值", color: "#34C759" },
      admin_adjust: { label: "管理员调整", color: "#007AFF" },
      consumption: { label: "消费扣除", color: "#FF3B30" }
    };
  }

  @action
  stopPropagation(event) {
    event.stopPropagation();
  }

  @action
  hideSuccessMessage() {
    this.showSuccessMessage = false;
  }

  @action
  goToCoinPage() {
    this.router.transitionTo("coin");
  }

  @action
  refreshData() {
    this.completedInvoicesList = [];
    this.completedInvoicesPage = 0;
    this.router.refresh();
  }

  @action
  openProcessInvoiceModal(invoice) {
    this.selectedInvoiceId = invoice.id;
    this.invoiceUrl = "";
    this.showProcessInvoiceModal = true;
  }

  @action
  closeProcessInvoiceModal() {
    this.showProcessInvoiceModal = false;
    this.selectedInvoiceId = null;
    this.invoiceUrl = "";
  }

  @action
  updateInvoiceUrl(event) {
    this.invoiceUrl = event.target.value;
  }

  @action
  async processInvoice() {
    const invoiceUrl = this.invoiceUrl.trim();

    if (!invoiceUrl) {
      alert("请输入发票URL");
      return;
    }

    this.isLoading = true;

    try {
      const result = await ajax("/coin/admin/process_invoice.json", {
        type: "POST",
        data: {
          id: this.selectedInvoiceId,
          invoice_url: invoiceUrl
        }
      });

      if (result.success) {
        this.successMessage = "发票处理成功！";
        this.showSuccessMessage = true;
        this.closeProcessInvoiceModal();
        setTimeout(() => { this.showSuccessMessage = false; }, 3000);
        this.refreshData();
      }
    } catch (error) {
      console.error("处理发票失败:", error);
      alert("处理失败: " + (error.jqXHR?.responseJSON?.errors?.[0] || error.message));
    } finally {
      this.isLoading = false;
    }
  }

  @action
  updateAdjustUsername(event) {
    this.adjustUsername = event.target.value;
  }

  @action
  updateAdjustAmount(event) {
    this.adjustAmount = event.target.value;
  }

  @action
  updateAdjustReason(event) {
    this.adjustReason = event.target.value;
  }

  @action
  toggleMarkAsRecharge(event) {
    this.markAsRecharge = event.target.checked;
  }

  @action
  async adjustPoints() {
    const username = this.adjustUsername.trim();
    const amount = parseInt(this.adjustAmount);
    const reason = this.adjustReason || "管理员调整";
    const markAsRecharge = this.markAsRecharge;

    if (!username) {
      alert("请输入用户名");
      return;
    }

    if (!amount || amount === 0) {
      alert("请输入有效的调整数量");
      return;
    }

    this.isLoading = true;

    try {
      const result = await ajax("/coin/admin/adjust_points.json", {
        type: "POST",
        data: { username, amount, reason, mark_as_recharge: markAsRecharge }
      });

      if (result.success) {
        this.successMessage = `积分调整成功！${amount > 0 ? '+' : ''}${amount}`;
        this.showSuccessMessage = true;
        this.adjustUsername = "";
        this.adjustAmount = "";
        this.adjustReason = "";
        this.markAsRecharge = false;
        setTimeout(() => { this.showSuccessMessage = false; }, 3000);
        this.refreshData();
      }
    } catch (error) {
      console.error("调整积分失败:", error);
      alert("调整失败: " + (error.jqXHR?.responseJSON?.errors?.[0] || error.message));
    } finally {
      this.isLoading = false;
    }
  }

  @action
  updateQueryUsername(event) {
    this.queryUsername = event.target.value;
  }

  @action
  async queryUserBalance() {
    const username = this.queryUsername.trim();

    if (!username) {
      alert("请输入用户名");
      return;
    }

    this.isLoading = true;

    try {
      const [balanceResult, transactionsResult] = await Promise.all([
        ajax("/coin/admin/user_balance.json", {
          type: "GET",
          data: { username }
        }),
        ajax("/coin/admin/user_transactions.json", {
          type: "GET",
          data: { username, limit: 20 }
        })
      ]);

      if (balanceResult.success && transactionsResult.success) {
        this.queryResult = {
          username: balanceResult.username,
          balance: balanceResult.balance,
          transactions: transactionsResult.transactions,
          total: transactionsResult.total
        };
        this.showQueryResult = true;
      }
    } catch (error) {
      console.error("查询用户失败:", error);
      alert("查询失败: " + (error.jqXHR?.responseJSON?.errors?.[0] || error.message));
    } finally {
      this.isLoading = false;
    }
  }

  @action
  closeQueryResult() {
    this.showQueryResult = false;
    this.queryResult = null;
    this.queryUsername = "";
  }

  // 已处理发票相关方法
  @action
  async loadMoreCompletedInvoices() {
    if (this.isLoadingMore) return;
    
    this.isLoadingMore = true;
    const nextOffset = (this.completedInvoicesPage + 1) * 20;

    try {
      const result = await ajax("/coin/admin/completed_invoices.json", {
        type: "GET",
        data: { limit: 20, offset: nextOffset }
      });

      if (result.success) {
        // 初始化列表（如果是第一次加载更多）
        if (this.completedInvoicesList.length === 0) {
          this.completedInvoicesList = [...(this.model?.completedInvoices || [])];
        }
        this.completedInvoicesList = [...this.completedInvoicesList, ...result.invoices];
        this.completedInvoicesPage = this.completedInvoicesPage + 1;
        this.hasMoreCompletedInvoices = result.has_more;
      }
    } catch (error) {
      console.error("加载更多已处理发票失败:", error);
      alert("加载失败: " + (error.jqXHR?.responseJSON?.errors?.[0] || error.message));
    } finally {
      this.isLoadingMore = false;
    }
  }

  @action
  openEditInvoiceModal(invoice) {
    this.editingInvoice = invoice;
    this.editInvoiceUrl = invoice.invoice_url || "";
    this.showEditInvoiceModal = true;
  }

  @action
  closeEditInvoiceModal() {
    this.showEditInvoiceModal = false;
    this.editingInvoice = null;
    this.editInvoiceUrl = "";
  }

  @action
  updateEditInvoiceUrl(event) {
    this.editInvoiceUrl = event.target.value;
  }

  @action
  async saveInvoiceUrl() {
    const newUrl = this.editInvoiceUrl.trim();

    if (!newUrl) {
      alert("请输入发票URL");
      return;
    }

    this.isLoading = true;

    try {
      const result = await ajax("/coin/admin/update_invoice_url.json", {
        type: "POST",
        data: {
          id: this.editingInvoice.id,
          invoice_url: newUrl
        }
      });

      if (result.success) {
        this.successMessage = "发票URL更新成功！";
        this.showSuccessMessage = true;
        this.closeEditInvoiceModal();
        setTimeout(() => { this.showSuccessMessage = false; }, 3000);
        this.refreshData();
      }
    } catch (error) {
      console.error("更新发票URL失败:", error);
      alert("更新失败: " + (error.jqXHR?.responseJSON?.errors?.[0] || error.message));
    } finally {
      this.isLoading = false;
    }
  }

  // 查看发票详情
  @action
  viewInvoiceDetail(invoice) {
    this.selectedInvoiceDetail = invoice;
    this.showInvoiceDetailModal = true;
  }

  @action
  closeInvoiceDetailModal() {
    this.showInvoiceDetailModal = false;
    this.selectedInvoiceDetail = null;
  }

  // 拒绝发票相关方法
  @action
  openRejectInvoiceModal(invoice) {
    this.rejectInvoiceId = invoice.id;
    this.rejectReason = "";
    this.showRejectInvoiceModal = true;
  }

  @action
  closeRejectInvoiceModal() {
    this.showRejectInvoiceModal = false;
    this.rejectInvoiceId = null;
    this.rejectReason = "";
  }

  @action
  updateRejectReason(event) {
    this.rejectReason = event.target.value;
  }

  @action
  async rejectInvoice() {
    this.isLoading = true;

    try {
      const result = await ajax("/coin/invoice/update_status.json", {
        type: "POST",
        data: {
          id: this.rejectInvoiceId,
          status: "rejected",
          reject_reason: this.rejectReason.trim() || "管理员拒绝"
        }
      });

      if (result.success) {
        this.successMessage = "发票申请已拒绝";
        this.showSuccessMessage = true;
        this.closeRejectInvoiceModal();
        setTimeout(() => { this.showSuccessMessage = false; }, 3000);
        this.refreshData();
      }
    } catch (error) {
      console.error("拒绝发票失败:", error);
      alert("操作失败: " + (error.jqXHR?.responseJSON?.errors?.[0] || error.message));
    } finally {
      this.isLoading = false;
    }
  }
}
