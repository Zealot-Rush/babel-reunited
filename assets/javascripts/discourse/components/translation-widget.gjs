import Component from "@glimmer/component";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";

/**
 * Translation widget component that displays available translations and allows users to switch between languages
 * @component TranslationWidget
 * @param {number} postId - The post ID
 * @param {Array} availableTranslations - Available translation languages
 * @param {Array} postTranslations - Post translation objects
 * @param {string} originalContent - The original post content
 */
export default class TranslationWidget extends Component {
  @service dialog;
  @service appEvents;
  
  @tracked selectedLanguage = null;
  @tracked showOriginal = true;
  @tracked loading = false;
  @tracked showLanguageSelector = false;

  get hasTranslations() {
    return this.args.postTranslations?.length > 0;
  }

  get originalContent() {
    return this.args.originalContent || "";
  }

  get supportedLanguages() {
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
  }

  @action
  showOriginalContent() {
    this.showOriginal = true;
    this.selectedLanguage = null;
  }

  @action
  showTranslation(translation) {
    this.showOriginal = false;
    this.selectedLanguage = translation.language;
  }

  @action
  toggleLanguageSelector() {
    this.showLanguageSelector = !this.showLanguageSelector;
  }

  @action
  async translateToLanguage(targetLanguage) {
    this.loading = true;
    this.showLanguageSelector = false;

    try {
      const result = await ajax(
        `/ai-translator/posts/${this.args.postId}/translations`,
        {
          type: "POST",
          data: { target_language: targetLanguage },
        }
      );

      if (result.error) {
        throw new Error(result.error);
      }

      // Refresh the page to show new translation
      window.location.reload();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  @action
  async deleteTranslation(translation) {
    const confirmed = await this.dialog.confirm({
      message: I18n.t("js.divine_rapier_ai_translator.confirm_delete"),
      didConfirm: () => true,
      didCancel: () => false,
    });

    if (!confirmed) {
      return;
    }

    try {
      await ajax(
        `/ai-translator/posts/${this.args.postId}/translations/${translation.language}`,
        {
          type: "DELETE",
        }
      );

      // Switch back to original if this was the selected translation
      if (this.selectedLanguage === translation.language) {
        this.showOriginalContent();
      }

      // Refresh the page
      window.location.reload();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async refreshTranslation(translation) {
    this.loading = true;

    try {
      // Delete existing translation and create a new one
      await ajax(
        `/ai-translator/posts/${this.args.postId}/translations/${translation.language}`,
        {
          type: "DELETE",
        }
      );

      const result = await ajax(
        `/ai-translator/posts/${this.args.postId}/translations`,
        {
          type: "POST",
          data: { target_language: translation.language },
        }
      );

      if (result.error) {
        throw new Error(result.error);
      }

      // Refresh the page
      window.location.reload();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  getLanguageName(code) {
    const language = this.supportedLanguages.find(lang => lang.code === code);
    return language?.name || code.toUpperCase();
  }

  confidencePercentage(confidence) {
    return Math.round(confidence * 100);
  }
}
