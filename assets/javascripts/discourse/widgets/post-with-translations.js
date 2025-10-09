import { h } from "virtual-dom";
import { createWidget } from "discourse/widgets/widget";

/**
 * Extended post widget that includes translation functionality
 * This extends the default post widget to include translation components
 */
export default createWidget("post", {
  tagName: "article.boxed",

  buildKey: (attrs) => `post-${attrs.id}`,

  html(attrs, state) {
    // Call the original post widget html method
    const originalHtml = this._super(attrs, state);

    // Add translation integration
    const translationHtml = this.renderTranslationIntegration(attrs);

    // Insert translation components after the post content
    return this.insertTranslationComponents(originalHtml, translationHtml);
  },

  renderTranslationIntegration(attrs) {
    const { show_translation_widget, show_translation_button } = attrs;

    if (!show_translation_widget && !show_translation_button) {
      return null;
    }

    return h("div.post-translation-integration", [
      show_translation_button && this.renderTranslationButton(attrs),
      show_translation_widget && this.renderTranslationWidget(attrs),
    ]);
  },

  renderTranslationButton(attrs) {
    return h("div.post-translation-button-wrapper", [
      this.attach("translation-button", {
        postId: attrs.id,
        availableTranslations: attrs.available_translations || [],
      }),
    ]);
  },

  renderTranslationWidget(attrs) {
    return h("div.post-translation-widget-wrapper", [
      this.attach("translation-widget", {
        postId: attrs.id,
        availableTranslations: attrs.available_translations || [],
        postTranslations: attrs.post_translations || [],
      }),
    ]);
  },

  insertTranslationComponents(originalHtml, translationHtml) {
    if (!translationHtml) {
      return originalHtml;
    }

    // Find the post content area and insert translation components
    const modifiedHtml = originalHtml.map((node) => {
      if (
        node.tagName === "div" &&
        node.properties &&
        node.properties.className === "post-content"
      ) {
        // Insert translation components after post content
        return [node, h("div.post-translation-separator"), translationHtml];
      }
      return node;
    });

    return modifiedHtml;
  },
});
