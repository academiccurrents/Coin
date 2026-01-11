import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { service } from "@ember/service";

export default class CoinPayController extends Controller {
  @service router;
  @service siteSettings;
  @service currentUser;

  @tracked selectedPackageId = null;
  @tracked selectedPaymentType = "alipay";
  @tracked isLoading = false;
  @tracked showQrcodeModal = false;
  @tracked qrcodeUrl = "";
  @tracked currentOrderNo = "";
  @tracked pollingTimer = null;

  get selectedPackage() {
    if (!this.selectedPackageId) return null;
    return this.model?.packages?.find(p => p.id === this.selectedPackageId);
  }

  get totalAmount() {
    if (!this.selectedPackage) return "0.00";
    return this.selectedPackage.actual_price.toFixed(2);
  }

  get payDisabled() {
    return this.isLoading || !this.selectedPackageId || !this.selectedPaymentType;
  }

  get paymentTypeName() {
    const names = {
      alipay: "支付宝",
      wxpay: "微信",
      qqpay: "QQ钱包"
    };
    return names[this.selectedPaymentType] || this.selectedPaymentType;
  }

  @action
  goBack() {
    this.router.transitionTo("coin");
  }

  @action
  selectPackage(pkg) {
    this.selectedPackageId = pkg.id;
  }

  @action
  selectPaymentType(type) {
    this.selectedPaymentType = type;
  }

  @action
  async submitPayment() {
    if (!this.selectedPackageId) {
      alert("请选择充值套餐");
      return;
    }

    this.isLoading = true;

    try {
      const result = await ajax("/coin/pay/create_order.json", {
        type: "POST",
        data: {
          package_id: this.selectedPackageId,
          payment_type: this.selectedPaymentType,
          mode: "page"
        }
      });

      if (result.success && result.pay_url) {
        this.currentOrderNo = result.out_trade_no;
        window.location.href = result.pay_url;
      } else {
        alert("创建订单失败");
      }
    } catch (error) {
      console.error("创建订单失败:", error);
      alert("创建订单失败: " + (error.jqXHR?.responseJSON?.errors?.[0] || error.message));
    } finally {
      this.isLoading = false;
    }
  }


  @action
  async submitQrcodePayment() {
    if (!this.selectedPackageId) {
      alert("请选择充值套餐");
      return;
    }

    this.isLoading = true;

    try {
      const result = await ajax("/coin/pay/create_order.json", {
        type: "POST",
        data: {
          package_id: this.selectedPackageId,
          payment_type: this.selectedPaymentType,
          mode: "qrcode"
        }
      });

      if (result.success && result.qrcode) {
        this.qrcodeUrl = result.qrcode;
        this.currentOrderNo = result.out_trade_no;
        this.showQrcodeModal = true;
        this.startPolling();
      } else if (result.success && result.pay_url) {
        window.location.href = result.pay_url;
      } else {
        alert("创建订单失败");
      }
    } catch (error) {
      console.error("创建订单失败:", error);
      alert("创建订单失败: " + (error.jqXHR?.responseJSON?.errors?.[0] || error.message));
    } finally {
      this.isLoading = false;
    }
  }

  @action
  closeQrcodeModal() {
    this.showQrcodeModal = false;
    this.qrcodeUrl = "";
    this.stopPolling();
  }

  @action
  stopPropagation(event) {
    event.stopPropagation();
  }

  startPolling() {
    this.stopPolling();
    this.pollingTimer = setInterval(() => this.checkOrderStatus(), 3000);
  }

  stopPolling() {
    if (this.pollingTimer) {
      clearInterval(this.pollingTimer);
      this.pollingTimer = null;
    }
  }

  async checkOrderStatus() {
    if (!this.currentOrderNo) return;

    try {
      const result = await ajax("/coin/pay/order_status.json", {
        data: { out_trade_no: this.currentOrderNo }
      });

      if (result.paid) {
        this.stopPolling();
        this.closeQrcodeModal();
        this.router.transitionTo("coin");
        alert(`支付成功！已充值 ${result.coin_amount} ${this.model.coinName}`);
      }
    } catch (error) {
      console.error("查询订单状态失败:", error);
    }
  }

  willDestroy() {
    super.willDestroy();
    this.stopPolling();
  }
}
