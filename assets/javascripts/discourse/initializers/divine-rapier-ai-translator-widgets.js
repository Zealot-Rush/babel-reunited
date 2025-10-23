import { withPluginApi } from "discourse/lib/plugin-api";
import LanguageTabsConnector from "../connectors/before-post-article/language-tabs";

/**
 * Initialize translation widgets and components
 * This initializer registers all translation-related widgets and components
 */
export default {
  name: "divine-rapier-ai-translator-widgets",

  initialize() {
    withPluginApi((api) => {
      // 使用 renderInOutlet 替换 post-content-cooked-html outlet
      // 现在总是渲染，让组件内部决定是否显示按钮
      api.renderInOutlet(
        "post-content-cooked-html",
        class extends LanguageTabsConnector {
          static shouldRender(args) {
            // 总是渲染组件，让组件内部决定是否显示按钮
            // 组件会检查用户是否禁用了AI翻译功能
            return true;
          }
        }
      );

      // Add translation components to post display
      api.addPostClassesCallback((attrs) => {
        if (attrs.show_translation_widget || attrs.show_translation_button) {
          return "has-translations";
        }
      });
    });
  },
};
