export default function () {
  this.route("coin", { path: "/coin" });
  this.route("coin-invoice", { path: "/coin/invoice" });
  this.route("coin-admin", { path: "/coin/admin" });
  this.route("coin-pay", { path: "/coin/pay" });
}
