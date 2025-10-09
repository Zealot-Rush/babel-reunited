import { withPluginApi } from "discourse/lib/plugin-api";

/**
 * Initialize translation widgets and components
 * This initializer registers all translation-related widgets and components
 */
export default {
  name: "divine-rapier-ai-translator-widgets",
  
  initialize() {
    withPluginApi("0.8.7", (api) => {
      // Register translation widgets
      api.registerWidget("translation-widget", {
        pluginId: "divine-rapier-ai-translator"
      });

      api.registerWidget("translation-button", {
        pluginId: "divine-rapier-ai-translator"
      });

      api.registerWidget("language-selector", {
        pluginId: "divine-rapier-ai-translator"
      });

      api.registerWidget("translation-display", {
        pluginId: "divine-rapier-ai-translator"
      });

      api.registerWidget("post-translation-integration", {
        pluginId: "divine-rapier-ai-translator"
      });

      // Add translation components to post display
      api.addPostClassesCallback((attrs) => {
        if (attrs.show_translation_widget || attrs.show_translation_button) {
          return "has-translations";
        }
      });

      // Add translation button to post menu
      api.addPostMenuButton("translation", (post) => {
        if (!post.show_translation_button) {
          return;
        }

        return {
          action: "showTranslationOptions",
          icon: "globe",
          label: "js.divine_rapier_ai_translator.translate",
          className: "translation-button",
          position: "first"
        };
      });

      // Add translation widget to post content
      api.addPostContentsCallback((post) => {
        if (!post.show_translation_widget) {
          return;
        }

        return {
          component: "post-translation-integration",
          attrs: {
            postId: post.id,
            availableTranslations: post.available_translations,
            postTranslations: post.post_translations
          }
        };
      });

      // Add translation service
      api.registerService("translation-api", {
        pluginId: "divine-rapier-ai-translator"
      });

      // Add translation actions to post menu
      api.addPostMenuAction("translate", (post) => {
        if (!post.show_translation_button) {
          return;
        }

        return {
          action: "translatePost",
          icon: "globe",
          label: "js.divine_rapier_ai_translator.translate",
          className: "translate-post-button"
        };
      });

      // Add translation display to post content
      api.addPostContentsCallback((post) => {
        if (!post.show_translation_widget || !post.post_translations?.length) {
          return;
        }

        return {
          component: "translation-display",
          attrs: {
            postId: post.id,
            translations: post.post_translations,
            originalContent: post.cooked
          }
        };
      });

      // Add keyboard shortcuts for translation
      api.addKeyboardShortcut("t", "translatePost", {
        help: "js.divine_rapier_ai_translator.translate_shortcut"
      });

      // Add translation to post actions
      api.addPostActionButton("translate", (post) => {
        if (!post.show_translation_button) {
          return;
        }

        return {
          action: "translatePost",
          icon: "globe",
          label: "js.divine_rapier_ai_translator.translate",
          className: "translate-post-action"
        };
      });

      // Add translation to post footer
      api.addPostFooterCallback((post) => {
        if (!post.show_translation_widget) {
          return;
        }

        return {
          component: "translation-widget",
          attrs: {
            postId: post.id,
            availableTranslations: post.available_translations,
            postTranslations: post.post_translations
          }
        };
      });
    });
  }
};

