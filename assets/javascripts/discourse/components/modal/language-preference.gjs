import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DModal from "discourse/components/d-modal";
import DButton from "discourse/components/d-button";
import ComboBox from "select-kit/components/combo-box";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import { fn } from "@ember/helper";

export default class LanguagePreferenceModal extends Component {
  @service currentUser;
  @service modal;
  
  @tracked selectedLanguage = null;
  @tracked saving = false;

  get availableLanguages() {
    return [
      { name: "English", value: "en" },
      { name: "中文", value: "zh" },
      { name: "日本語", value: "ja" },
      { name: "한국어", value: "ko" },
      { name: "Español", value: "es" },
      { name: "Français", value: "fr" },
      { name: "Deutsch", value: "de" },
      { name: "Русский", value: "ru" },
      { name: "Português", value: "pt" },
      { name: "Italiano", value: "it" },
      { name: "العربية", value: "ar" },
      { name: "हिन्दी", value: "hi" }
    ];
  }

  get saveDisabled() {
    return !this.selectedLanguage || this.saving;
  }

  @action
  async saveLanguage() {
    this.saving = true;
    
    try {
      await ajax("/ai-translator/user-preferred-language", {
        type: "POST",
        data: {
          language: this.selectedLanguage
        }
      });
      
      // 标记为已显示
      localStorage.setItem("language_preference_tip_shown", "true");
      
      this.modal.close();

    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  @action
  skip() {
    localStorage.setItem("language_preference_tip_shown", "true");
    this.modal.close();
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{i18n "divine_rapier_ai_translator.language_preference_modal.title"}}
      class="language-preference-modal"
    >
      <:body>
        <p>{{i18n "divine_rapier_ai_translator.language_preference_modal.description"}}</p>
        
        <div class="controls">
          <label for="language-select">
            {{i18n "divine_rapier_ai_translator.language_preference_modal.select_language"}}
          </label>
          <ComboBox
            @valueProperty="value"
            @content={{this.availableLanguages}}
            @value={{this.selectedLanguage}}
            @id="language-select"
            @onChange={{fn (mut this.selectedLanguage)}}
          />
        </div>
      </:body>
      
      <:footer>
        <DButton
          @action={{this.saveLanguage}}
          @disabled={{this.saveDisabled}}
          @label="divine_rapier_ai_translator.language_preference_modal.save"
          @icon="check"
          class="btn-primary"
        />
        <DButton
          @action={{this.skip}}
          @label="divine_rapier_ai_translator.language_preference_modal.skip"
          class="btn-flat"
        />
      </:footer>
    </DModal>
  </template>
}
