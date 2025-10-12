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
      // 通过 shouldRender 控制只在有翻译时渲染
      api.renderInOutlet(
        "post-content-cooked-html",
        class extends LanguageTabsConnector {
          static shouldRender(args) {
            console.log("🔍 DEBUG: shouldRender called with args:", args);

            // 只有当帖子有翻译数据时才替换内容
            const hasTranslationData =
              args.post?.post_translations &&
              args.post.post_translations.length > 0;

            const hasTranslationFlag =
              args.post?.show_translation_widget ||
              args.post?.show_translation_button;

            return hasTranslationFlag && hasTranslationData;
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
