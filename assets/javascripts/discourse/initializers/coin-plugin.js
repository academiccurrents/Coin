import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "coin-plugin",

  initialize() {
    console.log("🪙 Coin Plugin loaded successfully!");

    withPluginApi("1.0.0", (api) => {
      console.log("🪙 Coin Plugin API initialized");
    });
  }
};