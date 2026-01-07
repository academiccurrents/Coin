import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default class CoinInvoiceRoute extends Route {
  async model() {
    try {
      const result = await ajax("/coin/invoice/list.json");

      return {
        invoices: result.invoices || [],
        total: result.total || 0
      };
    } catch (error) {
      console.error("加载发票数据失败:", error);
      return {
        invoices: [],
        total: 0,
        error: true
      };
    }
  }
}