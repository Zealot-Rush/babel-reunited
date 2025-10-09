import { h } from "virtual-dom";
import { createWidget } from "discourse/widgets/widget";

/**
 * Post translation integration widget
 * Integrates translation components into Discourse post display
 */
export default createWidget("post-translation-integration", {
  tagName: "div.post-translation-integration",

  buildKey: (attrs) => `post-translation-integration-${attrs.id}`,

  html(attrs) {
    const { show_translation_widget, show_translation_button } = attrs;

    if (!show_translation_widget && !show_translation_button) {
      return null;
    }

    return h("div.post-translation-container", [
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
});
