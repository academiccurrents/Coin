import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { service } from "@ember/service";

export default class CoinController extends Controller {
  @service router;
  @service siteSettings;
  @service currentUser;
  
  queryParams = ["payment"];
  @tracked payment = null;
  
  @tracked isLoading = false;
  @tracked showInvoiceModal = false;
  @tracked selectedTransactionId = null;
  @tracked showSuccessMessage = false;
  @tracked successMessage = "";

  get paymentSuccess() {
    return this.model?.paymentStatus === "success";
  }

  get paymentFailed() {
    return this.model?.paymentStatus === "failed" || this.model?.paymentStatus === "error";
  }

  get formattedBalance() {
    return (this.model?.balance || 0).toLocaleString();
  }

  get coinInvoiceEnabled() {
    return this.siteSettings?.coin_invoice_enabled === true;
  }

  // 获取可开票的充值记录（只有recharge类型且金额>0且未申请过发票的）
  get invoiceableTransactions() {
    const transactions = this.model?.transactions || [];
    return transactions.filter(t => 
      t.transaction_type === "recharge" && 
      t.amount > 0 && 
      !t.invoice_requested
    );
  }

  get submitDisabled() {
    return this.isLoading || !this.selectedTransactionId;
  }

  @action
  stopPropagation(event) {
    event.stopPropagation();
  }

  @action
  openInvoiceModal() {
    this.showInvoiceModal = true;
    this.selectedTransactionId = null;
  }

  @action
  closeInvoiceModal() {
    this.showInvoiceModal = false;
    this.selectedTransactionId = null;
  }

  @action
  selectTransaction(transaction) {
    this.selectedTransactionId = transaction.id;
  }

  @action
  openInvoiceFromTransactionModal(transaction) {
    this.selectedTransactionId = transaction.id;
    this.showInvoiceModal = true;
  }

  @action
  async submitInvoiceRequest() {
    if (!this.selectedTransactionId) {
      alert("请选择要申请发票的充值记录");
      return;
    }

    this.isLoading = true;

    try {
      const result = await ajax("/coin/invoice/create_from_transaction.json", {
        type: "POST",
        data: {
          transaction_id: this.selectedTransactionId
        }
      });

      if (result.success) {
        this.successMessage = "发票申请提交成功！";
        this.showSuccessMessage = true;
        this.closeInvoiceModal();
        setTimeout(() => { this.showSuccessMessage = false; }, 3000);
        this.router.refresh();
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
    this.router.transitionTo("coin-invoice");
  }

  @action
  goToAdminPage() {
    this.router.transitionTo("coin-admin");
  }

  @action
  goToPayPage() {
    window.location.href = "/coin/pay";
  }

  @action
  refreshData() {
    this.router.refresh();
  }
}
