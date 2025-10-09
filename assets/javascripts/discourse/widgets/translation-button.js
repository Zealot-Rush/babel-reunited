import { h } from "virtual-dom";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { createWidget } from "discourse/widgets/widget";

/**
 * Translation button widget that provides quick translation actions
 * @component translation-button
 * @param {Object} attrs - Widget attributes
 * @param {number} attrs.postId - The post ID
 * @param {Array} attrs.availableTranslations - Available translation languages
 */
export default createWidget("translation-button", {
  tagName: "div.ai-translation-button",

  buildKey: (attrs) => `translation-button-${attrs.postId}`,

  defaultState() {
    return {
      loading: false,
      showQuickLanguages: false,
    };
  },

  html(attrs, state) {
    return h("div.ai-translation-button-container", [
      this.renderMainButton(attrs, state),
      this.renderQuickLanguages(attrs, state),
    ]);
  },

  renderMainButton(attrs, state) {
    const { availableTranslations } = attrs;
    const hasTranslations =
      availableTranslations && availableTranslations.length > 0;

    if (state.loading) {
      return h("button.btn.btn-primary.ai-translation-main-btn.loading", [
        h("i.fa.fa-spinner.fa-spin"),
        h("span", this.i18n("js.divine_rapier_ai_translator.translating")),
      ]);
    }

    return h(
      "button.btn.btn-primary.ai-translation-main-btn",
      {
        className: hasTranslations ? "has-translations" : "",
        onclick: () => this.toggleQuickLanguages(),
      },
      [
        h("i.fa", {
          className: hasTranslations ? "fa-globe" : "fa-plus",
        }),
        h("span", this.getButtonText(attrs)),
      ]
    );
  },

  renderQuickLanguages(attrs, state) {
    if (!state.showQuickLanguages) {
      return null;
    }

    const quickLanguages = this.getQuickLanguages();

    return h("div.ai-quick-languages", [
      h("div.ai-quick-languages-header", [
        h("span", this.i18n("js.divine_rapier_ai_translator.quick_translate")),
        h(
          "button.btn.btn-sm.btn-secondary.ai-close-quick",
          {
            onclick: () => this.toggleQuickLanguages(),
          },
          [h("i.fa.fa-times")]
        ),
      ]),
      h(
        "div.ai-quick-language-grid",
        quickLanguages.map((lang) =>
          h(
            "button.btn.btn-outline.ai-quick-language",
            {
              onclick: () => this.quickTranslate(attrs, lang.code),
            },
            [
              h("span.ai-quick-language-name", lang.name),
              h("span.ai-quick-language-code", lang.code),
            ]
          )
        )
      ),
    ]);
  },

  getButtonText(attrs) {
    const { availableTranslations } = attrs;

    if (availableTranslations && availableTranslations.length > 0) {
      return this.i18n("js.divine_rapier_ai_translator.translated");
    }

    return this.i18n("js.divine_rapier_ai_translator.translate");
  },

  getQuickLanguages() {
    return [
      { code: "zh", name: "中文" },
      { code: "en", name: "English" },
      { code: "ja", name: "日本語" },
      { code: "ko", name: "한국어" },
      { code: "es", name: "Español" },
      { code: "fr", name: "Français" },
    ];
  },

  toggleQuickLanguages() {
    this.state.showQuickLanguages = !this.state.showQuickLanguages;
    this.scheduleRerender();
  },

  async quickTranslate(attrs, targetLanguage) {
    this.state.loading = true;
    this.state.showQuickLanguages = false;
    this.scheduleRerender();

    try {
      const result = await ajax(
        `/ai-translator/posts/${attrs.postId}/translations`,
        {
          type: "POST",
          data: { target_language: targetLanguage },
        }
      );

      if (result.error) {
        throw new Error(result.error);
      }

      // Show success message
      this.appEvents.trigger("notifications:added", {
        message: this.i18n(
          "js.divine_rapier_ai_translator.translation_success",
          {
            language: targetLanguage.toUpperCase(),
          }
        ),
        type: "success",
      });

      // Refresh the post to show new translation
      this.sendWidgetAction("refreshPost");
    } catch (error) {
      this.state.error = error.message;
      popupAjaxError(error);
    } finally {
      this.state.loading = false;
      this.scheduleRerender();
    }
  },
});
