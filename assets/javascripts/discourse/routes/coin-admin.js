import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default class CoinAdminRoute extends Route {
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
      console.error("错误详情:", error.jqXHR?.responseText || error.message);
      return {
        statistics: {},
        recentTransactions: [],
        pendingInvoices: [],
        error: true,
        errorMessage: error.jqXHR?.responseJSON?.errors?.[0] || error.message
      };
    }
  }
}