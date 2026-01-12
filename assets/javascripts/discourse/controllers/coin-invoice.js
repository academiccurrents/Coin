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
  
  // 申请发票弹窗
  @tracked showApplyModal = false;
  @tracked eligibleOrders = [];
  @tracked selectedOrder = null;
  @tracked invoiceType = "personal";
  @tracked invoiceTitle = "";
  @tracked idNumber = "";
  @tracked taxNumber = "";
  
  // 编辑发票弹窗
  @tracked showEditModal = false;
  @tracked editingInvoice = null;
  
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

  get canSubmitApply() {
    if (!this.selectedOrder) return false;
    if (!this.invoiceTitle.trim()) return false;
    if (this.isPersonal && !this.idNumber.trim()) return false;
    if (!this.isPersonal && !this.taxNumber.trim()) return false;
    return true;
  }

  get canSubmitEdit() {
    if (!this.editingInvoice) return false;
    if (!this.invoiceTitle.trim()) return false;
    if (this.isPersonal && !this.idNumber.trim()) return false;
    if (!this.isPersonal && !this.taxNumber.trim()) return false;
    return true;
  }

  get canSubmitResubmit() {
    if (!this.resubmittingInvoice) return false;
    if (!this.invoiceTitle.trim()) return false;
    if (this.isPersonal && !this.idNumber.trim()) return false;
    if (!this.isPersonal && !this.taxNumber.trim()) return false;
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

  // 打开申请发票弹窗
  @action
  async openApplyModal() {
    this.isLoading = true;
    try {
      const result = await ajax("/coin/invoice/eligible_orders.json");
      this.eligibleOrders = result.orders || [];
      this.selectedOrder = null;
      this.invoiceType = "personal";
      this.invoiceTitle = "";
      this.idNumber = "";
      this.taxNumber = "";
      this.showApplyModal = true;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isLoading = false;
    }
  }

  @action
  closeApplyModal() {
    this.showApplyModal = false;
    this.selectedOrder = null;
  }

  @action
  selectOrder(order) {
    this.selectedOrder = order;
  }

  @action
  setInvoiceType(type) {
    this.invoiceType = type;
    // 切换类型时清空对应字段
    if (type === "personal") {
      this.taxNumber = "";
    } else {
      this.idNumber = "";
    }
  }

  @action
  updateInvoiceTitle(event) {
    this.invoiceTitle = event.target.value;
  }

  @action
  updateIdNumber(event) {
    this.idNumber = event.target.value;
  }

  @action
  updateTaxNumber(event) {
    this.taxNumber = event.target.value;
  }

  // 提交发票申请
  @action
  async submitApply() {
    if (!this.canSubmitApply || this.isLoading) return;

    this.isLoading = true;
    try {
      await ajax("/coin/invoice/create.json", {
        type: "POST",
        data: {
          amount: Math.round(this.selectedOrder.actual_price),
          reason: `订单 ${this.selectedOrder.out_trade_no} 发票申请`,
          out_trade_no: this.selectedOrder.out_trade_no,
          invoice_type: this.invoiceType,
          invoice_title: this.invoiceTitle.trim(),
          id_number: this.isPersonal ? this.idNumber.trim() : null,
          tax_number: !this.isPersonal ? this.taxNumber.trim() : null
        }
      });

      this.showApplyModal = false;
      this.successMessage = "发票申请提交成功！";
      this.showSuccessMessage = true;
      setTimeout(() => this.hideSuccessMessage(), 3000);
      this.refreshData();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isLoading = false;
    }
  }

  // 打开编辑发票弹窗
  @action
  openEditModal(invoice) {
    this.editingInvoice = invoice;
    this.invoiceType = invoice.invoice_type || "personal";
    this.invoiceTitle = invoice.invoice_title || "";
    this.idNumber = invoice.id_number || "";
    this.taxNumber = invoice.tax_number || "";
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
          id_number: this.isPersonal ? this.idNumber.trim() : null,
          tax_number: !this.isPersonal ? this.taxNumber.trim() : null
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
    this.idNumber = invoice.id_number || "";
    this.taxNumber = invoice.tax_number || "";
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
          id_number: this.isPersonal ? this.idNumber.trim() : null,
          tax_number: !this.isPersonal ? this.taxNumber.trim() : null
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
