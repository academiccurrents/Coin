import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";
import { service } from "@ember/service";

export default class CoinPayRoute extends Route {
  @service currentUser;
  @service router;

  beforeModel() {
    if (!this.currentUser) {
      this.router.transitionTo("login");
    }
  }

  async model() {
    try {
      const [packagesResult, channelsResult] = await Promise.all([
        ajax("/coin/pay/packages.json"),
        ajax("/coin/pay/channels.json")
      ]);

      return {
        packages: packagesResult.packages || [],
        discountRate: packagesResult.discount_rate || 100,
        hasDiscount: packagesResult.has_discount || false,
        balance: packagesResult.balance || 0,
        coinName: packagesResult.coin_name || "硬币",
        channels: channelsResult.channels || []
      };
    } catch (error) {
      console.error("加载充值数据失败:", error);
      return {
        packages: [],
        discountRate: 100,
        hasDiscount: false,
        balance: 0,
        coinName: "硬币",
        channels: [],
        error: true
      };
    }
  }
}
