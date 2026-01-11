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
      const [statisticsResult, transactionsResult, invoicesResult] = await Promise.all([
        ajax("/coin/admin/user_statistics.json"),
        ajax("/coin/admin/recent_transactions.json"),
        ajax("/coin/admin/pending_invoices.json")
      ]);

      return {
        statistics: statisticsResult.statistics || {},
        recentTransactions: transactionsResult.transactions || [],
        pendingInvoices: invoicesResult.invoices || []
      };
    } catch (error) {
      console.error("加载管理员数据失败:", error);
      return {
        statistics: { total_users: 0, total_balance: 0, average_balance: 0 },
        recentTransactions: [],
        pendingInvoices: [],
        error: true,
        errorMessage: error.jqXHR?.responseJSON?.errors?.[0] || error.message
      };
    }
  }
}
