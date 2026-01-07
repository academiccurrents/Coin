import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { service } from "@ember/service";

export default class CoinController extends Controller {
  @service router;
  @service siteSettings;
  @tracked isLoading = false;
  @tracked showInvoiceModal = false;
  @tracked showInvoiceFromTransactionModal = false;
  @tracked invoiceAmount = "";
  @tracked invoiceReason = "";
  @tracked selectedTransactionId = null;
  @tracked selectedTransactionAmount = 0;
  @tracked showSuccessMessage = false;
  @tracked successMessage = "";

  get formattedBalance() {
    return this.model.balance.toLocaleString();
  }

  get coinInvoiceEnabled() {
    return this.siteSettings?.coin_invoice_enabled === true;
  }

  get transactionTypes() {
    return {
      recharge: "充值",
      admin_adjust: "管理员调整",
      consumption: "消费扣除"
    };
  }

  get transactionTypeLabels() {
    return {
      recharge: { label: "充值", color: "#34C759" },
      admin_adjust: { label: "管理员调整", color: "#007AFF" },
      consumption: { label: "消费扣除", color: "#FF3B30" }
    };
  }

  @action
  openInvoiceModal() {
    this.showInvoiceModal = true;
    this.invoiceAmount = "";
    this.invoiceReason = "";
  }

  @action
  closeInvoiceModal() {
    this.showInvoiceModal = false;
    this.invoiceAmount = "";
    this.invoiceReason = "";
  }

  @action
  openInvoiceFromTransactionModal(transaction) {
    this.selectedTransactionId = transaction.id;
    this.selectedTransactionAmount = transaction.amount;
    this.invoiceAmount = transaction.amount.toString();
    this.invoiceReason = "从充值记录申请发票";
    this.showInvoiceFromTransactionModal = true;
  }

  @action
  closeInvoiceFromTransactionModal() {
    this.showInvoiceFromTransactionModal = false;
    this.selectedTransactionId = null;
    this.selectedTransactionAmount = 0;
    this.invoiceAmount = "";
    this.invoiceReason = "";
  }

  @action
  updateInvoiceAmount(event) {
    this.invoiceAmount = event.target.value;
  }

  @action
  updateInvoiceReason(event) {
    this.invoiceReason = event.target.value;
  }

  @action
  async submitInvoiceRequest() {
    const amount = parseInt(this.invoiceAmount);
    const reason = this.invoiceReason || "发票申请";

    if (!amount || amount <= 0) {
      alert("请输入有效的申请金额");
      return;
    }

    if (amount > this.model.balance) {
      alert("积分不足，当前余额: " + this.model.balance);
      return;
    }

    this.isLoading = true;

    try {
      const result = await ajax("/coin/invoice/create.json", {
        type: "POST",
        data: {
          amount: amount,
          reason: reason
        }
      });

      if (result.success) {
        this.successMessage = "发票申请提交成功！";
        this.showSuccessMessage = true;
        this.closeInvoiceModal();

        setTimeout(() => {
          this.showSuccessMessage = false;
        }, 3000);
      }
    } catch (error) {
      console.error("提交发票申请失败:", error);
      alert("提交失败: " + (error.jqXHR?.responseJSON?.errors?.[0] || error.message));
    } finally {
      this.isLoading = false;
    }
  }

  @action
  async submitInvoiceFromTransaction() {
    const amount = parseInt(this.invoiceAmount);
    const reason = this.invoiceReason || "从交易记录申请发票";

    if (!amount || amount <= 0) {
      alert("请输入有效的申请金额");
      return;
    }

    if (amount > this.model.balance) {
      alert("积分不足，当前余额: " + this.model.balance);
      return;
    }

    this.isLoading = true;

    try {
      const result = await ajax("/coin/invoice/create_from_transaction.json", {
        type: "POST",
        data: {
          transaction_id: this.selectedTransactionId,
          amount: amount,
          reason: reason
        }
      });

      if (result.success) {
        this.successMessage = "发票申请提交成功！";
        this.showSuccessMessage = true;
        this.closeInvoiceFromTransactionModal();

        setTimeout(() => {
          this.showSuccessMessage = false;
        }, 3000);
      }
    } catch (error) {
      console.error("提交发票申请失败:", error);
      alert("提交失败: " + (error.jqXHR?.responseJSON?.errors?.[0] || error.message));
    } finally {
      this.isLoading = false;
    }
  }

  @action
  hideSuccessMessage() {
    this.showSuccessMessage = false;
  }

  @action
  goToInvoicePage() {
    this.router.transitionTo("coin.invoice");
  }

  @action
  refreshData() {
    this.router.refresh();
  }
}