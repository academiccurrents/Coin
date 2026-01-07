import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { service } from "@ember/service";

export default class CoinInvoiceController extends Controller {
  @service router;
  @tracked isLoading = false;
  @tracked showSuccessMessage = false;
  @tracked successMessage = "";

  get pendingInvoices() {
    return this.model.invoices.filter(inv => inv.status === "pending");
  }

  get completedInvoices() {
    return this.model.invoices.filter(inv => inv.status === "completed");
  }

  get statusLabels() {
    return {
      pending: { label: "待开票", color: "#FF9500" },
      completed: { label: "已开票", color: "#34C759" }
    };
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
}