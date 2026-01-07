import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { service } from "@ember/service";

export default class CoinAdminController extends Controller {
  @service router;
  @tracked isLoading = false;
  @tracked showSuccessMessage = false;
  @tracked successMessage = "";
  @tracked showProcessInvoiceModal = false;
  @tracked selectedInvoiceId = null;
  @tracked invoiceUrl = "";
  @tracked adjustUsername = "";
  @tracked adjustAmount = "";
  @tracked adjustReason = "";
  @tracked queryUsername = "";
  @tracked queryResult = null;
  @tracked showQueryResult = false;

  get pendingInvoices() {
    return this.model.pendingInvoices || [];
  }

  get recentTransactions() {
    return this.model.recentTransactions || [];
  }

  get statistics() {
    return this.model.statistics || {};
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

        setTimeout(() => {
          this.showSuccessMessage = false;
        }, 3000);

        this.router.refresh();
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
  async adjustPoints() {
    const username = this.adjustUsername.trim();
    const amount = parseInt(this.adjustAmount);
    const reason = this.adjustReason || "管理员调整";

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
        data: {
          username: username,
          amount: amount,
          reason: reason
        }
      });

      if (result.success) {
        this.successMessage = `积分调整成功！${amount > 0 ? '+' : ''}${amount}`;
        this.showSuccessMessage = true;

        this.adjustUsername = "";
        this.adjustAmount = "";
        this.adjustReason = "";

        setTimeout(() => {
          this.showSuccessMessage = false;
        }, 3000);

        this.router.refresh();
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
          data: { username: username }
        }),
        ajax("/coin/admin/user_transactions.json", {
          type: "GET",
          data: { username: username, limit: 20 }
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
}