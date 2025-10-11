import { withPluginApi } from "discourse/lib/plugin-api";
import LanguageTabsConnector from "../connectors/before-post-article/language-tabs";


/**
 * Initialize translation widgets and components
 * This initializer registers all translation-related widgets and components
 */
export default {
  name: "divine-rapier-ai-translator-widgets",

  initialize() {
    console.log("🚀 Divine Rapier AI Translator widgets initializer loaded!");

    withPluginApi("0.8.7", (api) => {
      console.log("✅ Plugin API loaded for Divine Rapier AI Translator");

      // 方法1：使用内联组件来传递attrs
      api.renderBeforeWrapperOutlet("post-article", class extends LanguageTabsConnector {
        static shouldRender(args) {
          // 只有当帖子有翻译数据时才渲染
          return args.post?.show_translation_widget || args.post?.show_translation_button;
        }
      });

      // Add translation components to post display
      api.addPostClassesCallback((attrs) => {
        console.log("🔍 DEBUG: addPostClassesCallback called with attrs:", attrs);
        if (attrs.show_translation_widget || attrs.show_translation_button) {
          console.log("✅ DEBUG: Adding 'has-translations' class");
          return "has-translations";
        }
        console.log("❌ DEBUG: No translation classes to add");
      });
    });
  }
};
