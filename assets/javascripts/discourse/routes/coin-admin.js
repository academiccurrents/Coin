import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";
import { service } from "@ember/service";

export default class CoinAdminRoute extends Route {
  @service currentUser;
  @service router;

  beforeModel() {
    if (!this.currentUser?.admin) {
      this.router.transitionTo("coin");
    }
  }

  async model() {
    try {
      const [statisticsResult, transactionsResult, invoicesResult, completedInvoicesResult] = await Promise.all([
        ajax("/coin/admin/user_statistics.json"),
        ajax("/coin/admin/recent_transactions.json"),
        ajax("/coin/admin/pending_invoices.json"),
        ajax("/coin/admin/completed_invoices.json", { data: { limit: 20, offset: 0 } })
      ]);

      return {
        statistics: statisticsResult.statistics || {},
        recentTransactions: transactionsResult.transactions || [],
        pendingInvoices: invoicesResult.invoices || [],
        completedInvoices: completedInvoicesResult.invoices || [],
        completedInvoicesTotal: completedInvoicesResult.total || 0,
        hasMoreCompletedInvoices: completedInvoicesResult.has_more || false
      };
    } catch (error) {
      console.error("加载管理员数据失败:", error);
      return {
        statistics: { total_users: 0, total_balance: 0, total_recharge: 0, pending_invoices_count: 0 },
        recentTransactions: [],
        pendingInvoices: [],
        completedInvoices: [],
        completedInvoicesTotal: 0,
        hasMoreCompletedInvoices: false,
        error: true,
        errorMessage: error.jqXHR?.responseJSON?.errors?.[0] || error.message
      };
    }
  }
}
