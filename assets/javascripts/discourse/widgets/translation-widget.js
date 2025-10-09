import { service } from "@ember/service";
import { h } from "virtual-dom";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { createWidget } from "discourse/widgets/widget";

/**
 * Translation widget that displays available translations and allows users to switch between languages
 * @component translation-widget
 * @param {Object} attrs - Widget attributes
 * @param {number} attrs.postId - The post ID
 * @param {Array} attrs.availableTranslations - Available translation languages
 * @param {Array} attrs.postTranslations - Post translation objects
 */
export default createWidget("translation-widget", {
  dialog: service(),
  tagName: "div.ai-translation-widget",

  buildKey: (attrs) => `translation-widget-${attrs.postId}`,

  defaultState() {
    return {
      loading: false,
      error: null,
      currentLanguage: null,
      translations: [],
      showLanguageSelector: false,
    };
  },

  html(attrs, state) {
    const { availableTranslations } = attrs;

    if (!availableTranslations || availableTranslations.length === 0) {
      return this.renderNoTranslations();
    }

    return [
      this.renderTranslationHeader(attrs, state),
      this.renderLanguageSelector(attrs, state),
      this.renderTranslationContent(attrs, state),
    ];
  },

  renderNoTranslations() {
    return h("div.ai-translation-empty", [
      h("div.ai-translation-empty-content", [
        h("i.fa.fa-language"),
        h("span", this.i18n("js.divine_rapier_ai_translator.no_translations")),
      ]),
    ]);
  },

  renderTranslationHeader(attrs, state) {
    return h("div.ai-translation-header", [
      h("div.ai-translation-title", [
        h("i.fa.fa-language"),
        h(
          "span",
          this.i18n("js.divine_rapier_ai_translator.available_translations")
        ),
      ]),
      h("div.ai-translation-actions", [
        this.renderTranslateButton(attrs, state),
        this.renderLanguageToggle(attrs),
      ]),
    ]);
  },

  renderTranslateButton(attrs, state) {
    if (state.loading) {
      return h("button.btn.btn-primary.ai-translate-btn.loading", [
        h("i.fa.fa-spinner.fa-spin"),
        h("span", this.i18n("js.divine_rapier_ai_translator.translating")),
      ]);
    }

    return h(
      "button.btn.btn-primary.ai-translate-btn",
      {
        onclick: () => this.showLanguageSelector(),
      },
      [
        h("i.fa.fa-plus"),
        h("span", this.i18n("js.divine_rapier_ai_translator.translate")),
      ]
    );
  },

  renderLanguageToggle(attrs) {
    const { availableTranslations } = attrs;

    if (availableTranslations.length <= 1) {
      return null;
    }

    return h(
      "button.btn.btn-secondary.ai-language-toggle",
      {
        onclick: () => this.toggleLanguageSelector(),
      },
      [
        h("i.fa.fa-globe"),
        h("span", this.i18n("js.divine_rapier_ai_translator.select_language")),
      ]
    );
  },

  renderLanguageSelector(attrs, state) {
    if (!state.showLanguageSelector) {
      return null;
    }

    const { availableTranslations } = attrs;
    const supportedLanguages = this.getSupportedLanguages();

    return h("div.ai-language-selector", [
      h("div.ai-language-selector-header", [
        h("h4", this.i18n("js.divine_rapier_ai_translator.select_language")),
        h(
          "button.btn.btn-sm.btn-secondary.ai-close-selector",
          {
            onclick: () => this.toggleLanguageSelector(),
          },
          [h("i.fa.fa-times")]
        ),
      ]),
      h(
        "div.ai-language-options",
        supportedLanguages.map((lang) =>
          h(
            "button.btn.btn-outline.ai-language-option",
            {
              className: availableTranslations.includes(lang.code)
                ? "available"
                : "",
              onclick: () => this.translateToLanguage(attrs, state, lang.code),
            },
            [
              h("span.ai-language-name", lang.name),
              h("span.ai-language-code", lang.code),
              availableTranslations.includes(lang.code) &&
                h("i.fa.fa-check.ai-translation-exists"),
            ]
          )
        )
      ),
    ]);
  },

  renderTranslationContent(attrs, state) {
    const { postTranslations } = attrs;

    if (!postTranslations || postTranslations.length === 0) {
      return null;
    }

    return h("div.ai-translation-content", [
      h(
        "div.ai-translation-list",
        postTranslations.map((translation) =>
          this.renderTranslationItem(translation, attrs, state)
        )
      ),
    ]);
  },

  renderTranslationItem(translation, attrs, state) {
    const isActive = state.currentLanguage === translation.language;

    return h(
      "div.ai-translation-item",
      {
        className: isActive ? "active" : "",
      },
      [
        h("div.ai-translation-item-header", [
          h("span.ai-translation-language", translation.language.toUpperCase()),
          h("div.ai-translation-item-actions", [
            h(
              "button.btn.btn-sm.btn-outline.ai-view-translation",
              {
                onclick: () => this.viewTranslation(translation),
              },
              [
                h("i.fa.fa-eye"),
                h("span", this.i18n("js.divine_rapier_ai_translator.view")),
              ]
            ),
            h(
              "button.btn.btn-sm.btn-danger.ai-delete-translation",
              {
                onclick: () => this.deleteTranslation(translation, attrs),
              },
              [h("i.fa.fa-trash")]
            ),
          ]),
        ]),
        isActive &&
          h("div.ai-translation-item-content", [
            h("div.ai-translation-text", translation.translated_content),
            h("div.ai-translation-meta", [
              h(
                "span.ai-translation-provider",
                translation.translation_provider
              ),
              h(
                "span.ai-translation-date",
                new Date(translation.created_at).toLocaleDateString()
              ),
            ]),
          ]),
      ]
    );
  },

  getSupportedLanguages() {
    return [
      { code: "en", name: "English" },
      { code: "zh", name: "中文" },
      { code: "ja", name: "日本語" },
      { code: "ko", name: "한국어" },
      { code: "es", name: "Español" },
      { code: "fr", name: "Français" },
      { code: "de", name: "Deutsch" },
      { code: "ru", name: "Русский" },
      { code: "pt", name: "Português" },
      { code: "it", name: "Italiano" },
      { code: "ar", name: "العربية" },
      { code: "hi", name: "हिन्दी" },
    ];
  },

  showLanguageSelector() {
    this.state.showLanguageSelector = true;
    this.scheduleRerender();
  },

  toggleLanguageSelector() {
    this.state.showLanguageSelector = !this.state.showLanguageSelector;
    this.scheduleRerender();
  },

  viewTranslation(translation) {
    this.state.currentLanguage = translation.language;
    this.scheduleRerender();
  },

  async translateToLanguage(attrs, state, targetLanguage) {
    this.state.loading = true;
    this.state.error = null;
    this.state.showLanguageSelector = false;
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

      // Refresh the widget to show new translation
      this.sendWidgetAction("refreshTranslations");
    } catch (error) {
      this.state.error = error.message;
      popupAjaxError(error);
    } finally {
      this.state.loading = false;
      this.scheduleRerender();
    }
  },

  async deleteTranslation(translation, attrs) {
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
        `/ai-translator/posts/${attrs.postId}/translations/${translation.language}`,
        {
          type: "DELETE",
        }
      );

      // Refresh the widget
      this.sendWidgetAction("refreshTranslations");
    } catch (error) {
      popupAjaxError(error);
    }
  },
});
