export default function () {
  this.route("coin", { path: "/coin" }, function() {
    this.route("invoice", { path: "/invoice" });
    this.route("admin", { path: "/admin" });
  });
}