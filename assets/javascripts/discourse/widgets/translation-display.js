import { service } from "@ember/service";
import { h } from "virtual-dom";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { createWidget } from "discourse/widgets/widget";

/**
 * Translation display widget that shows translated content in posts
 * @component translation-display
 * @param {Object} attrs - Widget attributes
 * @param {number} attrs.postId - The post ID
 * @param {Array} attrs.translations - Available translations
 * @param {string} attrs.currentLanguage - Currently displayed language
 */
export default createWidget("translation-display", {
  dialog: service(),
  tagName: "div.ai-translation-display",

  buildKey: (attrs) => `translation-display-${attrs.postId}`,

  defaultState() {
    return {
      selectedLanguage: null,
      showOriginal: true,
      loading: false,
      error: null,
    };
  },

  html(attrs, state) {
    const { translations } = attrs;

    if (!translations || translations.length === 0) {
      return null;
    }

    return h("div.ai-translation-display-container", [
      this.renderLanguageTabs(attrs, state),
      this.renderTranslationContent(attrs, state),
    ]);
  },

  renderLanguageTabs(attrs, state) {
    const { translations } = attrs;

    return h("div.ai-translation-tabs", [
      h(
        "div.ai-translation-tab.ai-original-tab",
        {
          className: state.showOriginal ? "active" : "",
          onclick: () => this.showOriginal(),
        },
        [
          h("i.fa.fa-file-text"),
          h("span", this.i18n("js.divine_rapier_ai_translator.original")),
        ]
      ),
      ...translations.map((translation) =>
        this.renderTranslationTab(translation, attrs, state)
      ),
    ]);
  },

  renderTranslationTab(translation, attrs, state) {
    const isActive =
      state.selectedLanguage === translation.language && !state.showOriginal;

    return h(
      "div.ai-translation-tab",
      {
        className: isActive ? "active" : "",
        onclick: () => this.showTranslation(translation),
      },
      [
        h("i.fa.fa-globe"),
        h("span.ai-language-code", translation.language.toUpperCase()),
        h("span.ai-language-name", this.getLanguageName(translation.language)),
      ]
    );
  },

  renderTranslationContent(attrs, state) {
    const { translations } = attrs;

    if (state.showOriginal) {
      return this.renderOriginalContent(attrs);
    }

    const selectedTranslation = translations.find(
      (t) => t.language === state.selectedLanguage
    );
    if (!selectedTranslation) {
      return this.renderNoTranslation();
    }

    return this.renderTranslatedContent(selectedTranslation);
  },

  renderOriginalContent(attrs) {
    return h("div.ai-translation-content.ai-original-content", [
      h("div.ai-content-header", [
        h("i.fa.fa-file-text"),
        h("span", this.i18n("js.divine_rapier_ai_translator.original_content")),
      ]),
      h("div.ai-content-body", [
        h("div.ai-post-content", attrs.originalContent || ""),
      ]),
    ]);
  },

  renderTranslatedContent(translation) {
    return h("div.ai-translation-content.ai-translated-content", [
      h("div.ai-content-header", [
        h("i.fa.fa-globe"),
        h(
          "span",
          this.i18n("js.divine_rapier_ai_translator.translated_content", {
            language: this.getLanguageName(translation.language),
          })
        ),
        h("div.ai-translation-meta", [
          h("span.ai-translation-provider", translation.translation_provider),
          h(
            "span.ai-translation-confidence",
            `${Math.round(translation.confidence * 100)}%`
          ),
        ]),
      ]),
      h("div.ai-content-body", [
        h("div.ai-translated-text", translation.translated_content),
        this.renderTranslationFooter(translation),
      ]),
    ]);
  },

  renderTranslationFooter(translation) {
    return h("div.ai-translation-footer", [
      h("div.ai-translation-info", [
        h(
          "span.ai-translation-date",
          this.i18n("js.divine_rapier_ai_translator.translated_on", {
            date: new Date(translation.created_at).toLocaleDateString(),
          })
        ),
        h(
          "span.ai-translation-source",
          this.i18n("js.divine_rapier_ai_translator.source_language", {
            language: translation.source_language || "Auto-detected",
          })
        ),
      ]),
      h("div.ai-translation-actions", [
        h(
          "button.btn.btn-sm.btn-outline.ai-refresh-translation",
          {
            onclick: () => this.refreshTranslation(translation),
          },
          [
            h("i.fa.fa-refresh"),
            h("span", this.i18n("js.divine_rapier_ai_translator.refresh")),
          ]
        ),
        h(
          "button.btn.btn-sm.btn-danger.ai-delete-translation",
          {
            onclick: () => this.deleteTranslation(translation),
          },
          [
            h("i.fa.fa-trash"),
            h("span", this.i18n("js.divine_rapier_ai_translator.delete")),
          ]
        ),
      ]),
    ]);
  },

  renderNoTranslation() {
    return h("div.ai-translation-content.ai-no-translation", [
      h("div.ai-content-header", [
        h("i.fa.fa-exclamation-triangle"),
        h("span", this.i18n("js.divine_rapier_ai_translator.no_translation")),
      ]),
      h("div.ai-content-body", [
        h(
          "p",
          this.i18n("js.divine_rapier_ai_translator.translation_not_found")
        ),
      ]),
    ]);
  },

  getLanguageName(code) {
    const languages = {
      en: "English",
      zh: "中文",
      ja: "日本語",
      ko: "한국어",
      es: "Español",
      fr: "Français",
      de: "Deutsch",
      ru: "Русский",
      pt: "Português",
      it: "Italiano",
      ar: "العربية",
      hi: "हिन्दी",
    };
    return languages[code] || code.toUpperCase();
  },

  showOriginal() {
    this.state.showOriginal = true;
    this.state.selectedLanguage = null;
    this.scheduleRerender();
  },

  showTranslation(translation) {
    this.state.showOriginal = false;
    this.state.selectedLanguage = translation.language;
    this.scheduleRerender();
  },

  async refreshTranslation(translation) {
    this.state.loading = true;
    this.scheduleRerender();

    try {
      // Delete existing translation and create a new one
      await ajax(
        `/ai-translator/posts/${this.attrs.postId}/translations/${translation.language}`,
        {
          type: "DELETE",
        }
      );

      const result = await ajax(
        `/ai-translator/posts/${this.attrs.postId}/translations`,
        {
          type: "POST",
          data: { target_language: translation.language },
        }
      );

      if (result.error) {
        throw new Error(result.error);
      }

      // Refresh the widget
      this.sendWidgetAction("refreshTranslations");
    } catch (error) {
      this.state.error = error.message;
      popupAjaxError(error);
    } finally {
      this.state.loading = false;
      this.scheduleRerender();
    }
  },

  async deleteTranslation(translation) {
    const confirmed = await this.dialog.confirm({
      message: this.i18n("js.divine_rapier_ai_translator.confirm_delete"),
      didConfirm: () => true,
      didCancel: () => false,
    });

    if (!confirmed) {
      return;
    }

    try {
      await ajax(
        `/ai-translator/posts/${this.attrs.postId}/translations/${translation.language}`,
        {
          type: "DELETE",
        }
      );

      // Switch back to original if this was the selected translation
      if (this.state.selectedLanguage === translation.language) {
        this.showOriginal();
      }

      // Refresh the widget
      this.sendWidgetAction("refreshTranslations");
    } catch (error) {
      popupAjaxError(error);
    }
  },
});
