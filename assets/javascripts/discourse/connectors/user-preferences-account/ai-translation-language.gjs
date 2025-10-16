import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import { on } from "@ember/modifier";
import { eq } from "truth-helpers";
import { fn } from "@ember/helper";

export default class AiTranslationLanguage extends Component {
  static shouldRender(args, context) {
    return context.siteSettings.divine_rapier_ai_translator_enabled;
  }

  @service currentUser;
  @tracked saving = false;
  @tracked currentLanguage = null;

  constructor() {
    super(...arguments);
    this.loadCurrentLanguage();
  }

  async loadCurrentLanguage() {
    try {
      const response = await ajax("/ai-translator/user-preferred-language", {
        type: "GET"
      });
      this.currentLanguage = response.language || "en";
      console.log("🔍 DEBUG: Loaded current language:", this.currentLanguage);
    } catch (error) {
      console.error("Failed to load current language:", error);
      this.currentLanguage = "en";
    }
  }

  get languageOptions() {
    return [
      { value: "en", label: "English", flag: "🇺🇸" },
      { value: "zh", label: "中文", flag: "🇨🇳" },
      { value: "es", label: "Español", flag: "🇪🇸" }
    ];
  }

  get currentLanguageOption() {
    return this.languageOptions.find(opt => opt.value === this.currentLanguage) || this.languageOptions[0];
  }

  @action
  async changeLanguage(language) {
    console.log("🔍 DEBUG: Changing language to:", language);
    this.saving = true;
    
    try {
      await ajax("/ai-translator/user-preferred-language", {
        type: "POST",
        data: { language: language }
      });
      
      this.currentLanguage = language;
      console.log("✅ DEBUG: Language changed successfully to:", language);
      
      // 刷新currentUser数据
      if (this.currentUser) {
        this.currentUser.set("preferred_language", language);
      }
      
    } catch (error) {
      console.error("❌ DEBUG: Failed to change language:", error);
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  <template>
    <div class="control-group ai-translation-language">
      <label class="control-label">
        {{i18n "js.divine_rapier_ai_translator.preferences.ai_translation_language"}}
      </label>
      
      <div class="controls">
        <div class="language-selection">
          {{#each this.languageOptions as |option|}}
            <button
              type="button"
              class="language-option {{if (eq option.value this.currentLanguage) 'selected'}}"
              disabled={{this.saving}}
              {{on "click" (fn this.changeLanguage option.value)}}
              data-language="{{option.value}}"
              data-selected="{{if (eq option.value this.currentLanguage) 'true' 'false'}}"
            >
              <span class="flag">{{option.flag}}</span>
              <span class="label">{{option.label}}</span>
            </button>
          {{/each}}
        </div>
      </div>
      
      <div class="instructions">
        {{i18n "js.divine_rapier_ai_translator.preferences.ai_translation_language_description"}}
      </div>
      
      <!-- Debug info -->
      <div class="debug-info" style="margin-top: 10px; font-size: 12px; color: #999;">
        {{i18n "js.divine_rapier_ai_translator.preferences.current_language"}}: {{this.currentLanguage}}
      </div>
    </div>
  </template>
}
