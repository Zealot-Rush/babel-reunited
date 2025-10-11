import Component from "@glimmer/component";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";

/**
 * Translation button component for quick translation actions
 * @component TranslationButton
 * @param {number} postId - The post ID
 * @param {Array} availableTranslations - Available translation languages
 */
export default class TranslationButton extends Component {
  @service dialog;
  @service appEvents;
  @tracked showQuickLanguages = false;

  get hasTranslations() {
    return this.args.availableTranslations?.length > 0;
  }

  get buttonText() {
    if (this.hasTranslations) {
      return I18n.t("js.divine_rapier_ai_translator.translated");
    }
    return I18n.t("js.divine_rapier_ai_translator.translate");
  }

  get quickLanguages() {
    return [
      { code: "zh", name: "中文" },
      { code: "en", name: "English" },
      { code: "ja", name: "日本語" },
      { code: "ko", name: "한국어" },
      { code: "es", name: "Español" },
      { code: "fr", name: "Français" },
    ];
  }

  @action
  toggleQuickLanguages() {
    this.showQuickLanguages = !this.showQuickLanguages;
  }

  @action
  async quickTranslate(targetLanguage) {
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

      // Show success message
      this.appEvents.trigger("notifications:added", {
        message: I18n.t(
          "js.divine_rapier_ai_translator.translation_success",
          {
            language: targetLanguage.toUpperCase(),
          }
        ),
        type: "success",
      });

      // Refresh the post to show new translation
      window.location.reload();
    } catch (error) {
      popupAjaxError(error);
    }
  }
}
