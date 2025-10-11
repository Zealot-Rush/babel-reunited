import Component from "@glimmer/component";

/**
 * Post translation integration component for Glimmer post stream
 * @component PostTranslationIntegration
 * @param {number} postId - The post ID
 * @param {Array} availableTranslations - Available translation languages
 * @param {Array} postTranslations - Post translation objects
 * @param {string} originalContent - The original post content
 * @param {boolean} show_translation_widget - Whether to show the translation widget
 * @param {boolean} show_translation_button - Whether to show the translation button
 */
export default class PostTranslationIntegration extends Component {
  get hasTranslations() {
    return this.args.postTranslations?.length > 0;
  }

  get shouldShowWidget() {
    return this.args.show_translation_widget && this.hasTranslations;
  }

  get shouldShowButton() {
    return this.args.show_translation_button;
  }
}
