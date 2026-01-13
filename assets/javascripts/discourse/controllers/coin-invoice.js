import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class CoinInvoiceController extends Controller {
  @service router;
  @service currentUser;
  
  @tracked isLoading = false;
  @tracked showSuccessMessage = false;
  @tracked successMessage = "";
  
  // 编辑发票弹窗
  @tracked showEditModal = false;
  @tracked editingInvoice = null;
  @tracked invoiceType = "personal";
  @tracked invoiceTitle = "";
  @tracked email = "";
  @tracked phone = "";
  @tracked billingAddress = "";
  @tracked taxNumber = "";
  @tracked contactName = "";
  
  // 重新申请弹窗
  @tracked showResubmitModal = false;
  @tracked resubmittingInvoice = null;

  // 阻止事件冒泡
  @action
  stopPropagation(event) {
    event.stopPropagation();
  }

  get pendingInvoices() {
    return (this.model?.invoices || []).filter(inv => inv.status === "pending");
  }

  get completedInvoices() {
    return (this.model?.invoices || []).filter(inv => inv.status === "completed");
  }

  get rejectedInvoices() {
    return (this.model?.invoices || []).filter(inv => inv.status === "rejected");
  }

  get statusLabels() {
    return {
      pending: { label: "待开票", color: "#FF9500" },
      completed: { label: "已开票", color: "#34C759" },
      rejected: { label: "已拒绝", color: "#FF3B30" }
    };
  }

  get isPersonal() {
    return this.invoiceType === "personal";
  }

  get canSubmitEdit() {
    if (!this.editingInvoice) return false;
    if (!this.invoiceTitle.trim()) return false;
    if (!this.email.trim()) return false;
    if (!this.phone.trim()) return false;
    if (!this.billingAddress.trim()) return false;
    // 企业发票：联系人必填
    if (!this.isPersonal && !this.contactName.trim()) return false;
    return true;
  }

  get canSubmitResubmit() {
    if (!this.resubmittingInvoice) return false;
    if (!this.invoiceTitle.trim()) return false;
    if (!this.email.trim()) return false;
    if (!this.phone.trim()) return false;
    if (!this.billingAddress.trim()) return false;
    // 企业发票：联系人必填
    if (!this.isPersonal && !this.contactName.trim()) return false;
    return true;
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
  setInvoiceType(type) {
    this.invoiceType = type;
    // 切换类型时清空联系人字段
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

  // 打开编辑发票弹窗
  @action
  openEditModal(invoice) {
    this.editingInvoice = invoice;
    this.invoiceType = invoice.invoice_type || "personal";
    this.invoiceTitle = invoice.invoice_title || "";
    this.email = invoice.email || "";
    this.phone = invoice.phone || "";
    this.billingAddress = invoice.billing_address || "";
    this.taxNumber = invoice.tax_number || "";
    this.contactName = invoice.contact_name || "";
    this.showEditModal = true;
  }

  @action
  closeEditModal() {
    this.showEditModal = false;
    this.editingInvoice = null;
  }

  // 提交编辑
  @action
  async submitEdit() {
    if (!this.canSubmitEdit || this.isLoading) return;

    this.isLoading = true;
    try {
      await ajax(`/coin/invoice/update/${this.editingInvoice.id}.json`, {
        type: "PUT",
        data: {
          invoice_type: this.invoiceType,
          invoice_title: this.invoiceTitle.trim(),
          email: this.email.trim(),
          phone: this.phone.trim(),
          billing_address: this.billingAddress.trim(),
          tax_number: this.taxNumber.trim() || null,
          contact_name: !this.isPersonal ? this.contactName.trim() : null
        }
      });

      this.showEditModal = false;
      this.successMessage = "发票信息更新成功！";
      this.showSuccessMessage = true;
      setTimeout(() => this.hideSuccessMessage(), 3000);
      this.refreshData();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isLoading = false;
    }
  }

  // 打开重新申请弹窗
  @action
  openResubmitModal(invoice) {
    this.resubmittingInvoice = invoice;
    this.invoiceType = invoice.invoice_type || "personal";
    this.invoiceTitle = invoice.invoice_title || "";
    this.email = invoice.email || "";
    this.phone = invoice.phone || "";
    this.billingAddress = invoice.billing_address || "";
    this.taxNumber = invoice.tax_number || "";
    this.contactName = invoice.contact_name || "";
    this.showResubmitModal = true;
  }

  @action
  closeResubmitModal() {
    this.showResubmitModal = false;
    this.resubmittingInvoice = null;
  }

  // 提交重新申请
  @action
  async submitResubmit() {
    if (!this.canSubmitResubmit || this.isLoading) return;

    this.isLoading = true;
    try {
      await ajax(`/coin/invoice/resubmit/${this.resubmittingInvoice.id}.json`, {
        type: "POST",
        data: {
          invoice_type: this.invoiceType,
          invoice_title: this.invoiceTitle.trim(),
          email: this.email.trim(),
          phone: this.phone.trim(),
          billing_address: this.billingAddress.trim(),
          tax_number: this.taxNumber.trim() || null,
          contact_name: !this.isPersonal ? this.contactName.trim() : null
        }
      });

      this.showResubmitModal = false;
      this.successMessage = "重新申请成功，请等待审核！";
      this.showSuccessMessage = true;
      setTimeout(() => this.hideSuccessMessage(), 3000);
      this.refreshData();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isLoading = false;
    }
  }
}
