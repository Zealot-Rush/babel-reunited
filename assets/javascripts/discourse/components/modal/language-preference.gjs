import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DModal from "discourse/components/d-modal";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import { fn } from "@ember/helper";

export default class LanguagePreferenceModal extends Component {
  @service currentUser;
  @service modal;
  
  @tracked selectedLanguage = null;
  @tracked saving = false;


  get saveDisabled() {
    return !this.selectedLanguage || this.saving;
  }

  @action
  selectLanguage(language) {
    this.selectedLanguage = language;
    // 自动保存选中的语言
    this.saveLanguage();
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

  @action
  disable() {
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
          <label>
            {{i18n "divine_rapier_ai_translator.language_preference_modal.select_language"}}
          </label>
          <div class="language-buttons">
            <DButton
              @action={{fn this.selectLanguage "en"}}
              @icon="globe"
              class="btn-language"
            >
              English
            </DButton>
            <DButton
              @action={{fn this.selectLanguage "zh"}}
              @icon="globe"
              class="btn-language"
            >
              中文
            </DButton>
            <DButton
              @action={{fn this.selectLanguage "es"}}
              @icon="globe"
              class="btn-language"
            >
              Español
            </DButton>
          </div>
        </div>
      </:body>
      
      <:footer>
        <DButton
          @action={{this.disable}}
          @label="divine_rapier_ai_translator.language_preference_modal.disable"
          class="btn-flat"
        />
      </:footer>
    </DModal>
  </template>
}
