import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { service } from "@ember/service";
import I18n from "discourse-i18n";

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

  // 发票申请表单状态
  @tracked invoiceStep = 1;  // 1: 选择交易, 2: 填写信息
  @tracked invoiceType = "personal";  // "personal" | "company"
  @tracked invoiceTitle = "";  // 姓名或公司名称
  @tracked email = "";  // 电子邮箱
  @tracked phone = "";  // 电话
  @tracked billingAddress = "";  // 账单地址
  @tracked taxNumber = "";  // 税号（可选）
  @tracked contactName = "";  // 联系人（企业用）

  get currentLocale() {
    return I18n.currentLocale();
  }

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

  // 获取可开票的充值记录（只有recharge类型且金额>0且有out_trade_no且未申请过发票的）
  get invoiceableTransactions() {
    const transactions = this.model?.transactions || [];
    return transactions.filter(t => 
      t.transaction_type === "recharge" && 
      t.amount > 0 && 
      t.out_trade_no &&  // 必须有订单号才能申请发票
      !t.invoice_requested
    );
  }

  get submitDisabled() {
    return this.isLoading || !this.selectedTransactionId;
  }

  get isPersonalInvoice() {
    return this.invoiceType === "personal";
  }

  get canSubmitInvoice() {
    if (!this.selectedTransactionId) return false;
    if (this.invoiceStep === 1) return true;  // Step 1 只需选择交易
    if (!this.invoiceTitle.trim()) return false;
    if (!this.email.trim()) return false;
    if (!this.phone.trim()) return false;
    if (!this.billingAddress.trim()) return false;
    // 企业发票：联系人必填
    if (!this.isPersonalInvoice && !this.contactName.trim()) return false;
    return true;
  }

  get selectedTransaction() {
    if (!this.selectedTransactionId) return null;
    return this.invoiceableTransactions.find(t => t.id === this.selectedTransactionId);
  }

  @action
  stopPropagation(event) {
    event.stopPropagation();
  }

  @action
  openInvoiceModal() {
    this.showInvoiceModal = true;
    this.selectedTransactionId = null;
    this.invoiceStep = 1;
    this.invoiceType = "personal";
    this.invoiceTitle = "";
    this.email = "";
    this.phone = "";
    this.billingAddress = "";
    this.taxNumber = "";
    this.contactName = "";
  }

  @action
  closeInvoiceModal() {
    this.showInvoiceModal = false;
    this.selectedTransactionId = null;
    this.invoiceStep = 1;
    this.invoiceType = "personal";
    this.invoiceTitle = "";
    this.email = "";
    this.phone = "";
    this.billingAddress = "";
    this.taxNumber = "";
    this.contactName = "";
  }

  @action
  selectTransaction(transaction) {
    this.selectedTransactionId = transaction.id;
  }

  @action
  openInvoiceFromTransactionModal(transaction) {
    this.selectedTransactionId = transaction.id;
    this.invoiceStep = 1;
    this.invoiceType = "personal";
    this.invoiceTitle = "";
    this.email = "";
    this.phone = "";
    this.billingAddress = "";
    this.taxNumber = "";
    this.contactName = "";
    this.showInvoiceModal = true;
  }

  @action
  goToInvoiceStep2() {
    if (this.selectedTransactionId) {
      this.invoiceStep = 2;
    }
  }

  @action
  goToInvoiceStep1() {
    this.invoiceStep = 1;
  }

  @action
  setInvoiceType(type) {
    this.invoiceType = type;
    if (type === "personal") {
      this.contactName = "";
    }
  }

  @action
  updateInvoiceTitle(event) {
    this.invoiceTitle = event.target.value;
  }

  @action
  updateEmail(event) {
    this.email = event.target.value;
  }

  @action
  updatePhone(event) {
    this.phone = event.target.value;
  }

  @action
  updateBillingAddress(event) {
    this.billingAddress = event.target.value;
  }

  @action
  updateTaxNumber(event) {
    this.taxNumber = event.target.value;
  }

  @action
  updateContactName(event) {
    this.contactName = event.target.value;
  }

  @action
  async submitInvoiceRequest() {
    if (!this.canSubmitInvoice) {
      return;
    }

    // Step 1: 选择交易后进入 Step 2
    if (this.invoiceStep === 1) {
      this.goToInvoiceStep2();
      return;
    }

    // Step 2: 提交发票申请
    const transaction = this.selectedTransaction;
    if (!transaction) {
      alert(I18n.t("js.coin.invoice.select_record_error"));
      return;
    }

    this.isLoading = true;

    try {
      const result = await ajax("/coin/invoice/create.json", {
        type: "POST",
        data: {
          amount: transaction.amount,
          reason: `${I18n.t("js.coin.invoice.recharge_invoice")} - #${transaction.id}`,
          invoice_type: this.invoiceType,
          invoice_title: this.invoiceTitle.trim(),
          email: this.email.trim(),
          phone: this.phone.trim(),
          billing_address: this.billingAddress.trim(),
          tax_number: this.taxNumber.trim() || null,
          contact_name: !this.isPersonalInvoice ? this.contactName.trim() : null,
          out_trade_no: transaction.out_trade_no  // 使用交易的订单号
        }
      });

      if (result.success) {
        this.successMessage = I18n.t("js.coin.invoice.success");
        this.showSuccessMessage = true;
        this.closeInvoiceModal();
        setTimeout(() => { this.showSuccessMessage = false; }, 3000);
        this.router.refresh();
      }
    } catch (error) {
      console.error("提交发票申请失败:", error);
      alert(I18n.t("js.coin.invoice.submit_failed") + ": " + (error.jqXHR?.responseJSON?.errors?.[0] || error.message));
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
  toggleLanguage() {
    const newLocale = this.currentLocale === "zh_CN" ? "en" : "zh_CN";
    I18n.locale = newLocale;
    // 刷新页面以应用新语言
    window.location.reload();
  }

  @action
  refreshData() {
    this.router.refresh();
  }
}
