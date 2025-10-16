import { withPluginApi } from "discourse/lib/plugin-api";
import LanguageTabsConnector from "../connectors/before-post-article/language-tabs";

/**
 * Initialize translation widgets and components
 * This initializer registers all translation-related widgets and components
 */
export default {
  name: "divine-rapier-ai-translator-widgets",

  initialize() {
    // eslint-disable-next-line no-console
    console.log("🚀 Divine Rapier AI Translator widgets initializer loaded!");

    withPluginApi((api) => {
      // eslint-disable-next-line no-console
      console.log("✅ Plugin API loaded for Divine Rapier AI Translator");

      // 使用 renderInOutlet 替换 post-content-cooked-html outlet
      // 现在总是渲染，让组件内部决定是否显示按钮
      api.renderInOutlet(
        "post-content-cooked-html",
        class extends LanguageTabsConnector {
          static shouldRender(args) {
            console.log("🔍 DEBUG: shouldRender called with args:", args);
            console.log("🔍 DEBUG: post:", args.post);
            console.log("🔍 DEBUG: post_translations:", args.post?.post_translations);
            console.log("🔍 DEBUG: show_translation_widget:", args.post?.show_translation_widget);
            console.log("🔍 DEBUG: show_translation_button:", args.post?.show_translation_button);

            // 总是渲染组件，让组件内部决定是否显示按钮
            // 组件会检查用户是否禁用了AI翻译功能
            return true;
          }
        }
      );

      // Add translation components to post display
      api.addPostClassesCallback((attrs) => {
        // eslint-disable-next-line no-console
        console.log(
          "🔍 DEBUG: addPostClassesCallback called with attrs:",
          attrs
        );
        if (attrs.show_translation_widget || attrs.show_translation_button) {
          // eslint-disable-next-line no-console
          console.log("✅ DEBUG: Adding 'has-translations' class");
          return "has-translations";
        }
        // eslint-disable-next-line no-console
        console.log("❌ DEBUG: No translation classes to add");
      });
    });
  },
};
