import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";
import { service } from "@ember/service";

export default class CoinRoute extends Route {
  @service currentUser;

  async model() {
    if (!this.currentUser) {
      return {
        balance: 0,
        coinName: "硬币",
        transactions: [],
        needLogin: true
      };
    }

    try {
      const [balanceResult, transactionsResult] = await Promise.all([
        ajax("/coin/balance.json"),
        ajax("/coin/transactions.json")
      ]);

      return {
        balance: balanceResult.balance || 0,
        coinName: balanceResult.coin_name || "硬币",
        transactions: transactionsResult.transactions || []
      };
    } catch (error) {
      console.error("加载积分数据失败:", error);
      return {
        balance: 0,
        coinName: "硬币",
        transactions: [],
        error: true
      };
    }
  }
}
