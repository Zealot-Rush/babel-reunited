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
  @tracked enabled = true;
  @tracked showSavedNotice = false;

  savedNoticeTimerId = null;

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
      this.enabled = response.enabled !== false; // Default to true if not set
    } catch (error) {
      this.currentLanguage = "en";
      this.enabled = true;
    }
  }

  showSaved() {
    this.showSavedNotice = true;
    if (this.savedNoticeTimerId) {
      clearTimeout(this.savedNoticeTimerId);
    }
    this.savedNoticeTimerId = setTimeout(() => {
      this.showSavedNotice = false;
      this.savedNoticeTimerId = null;
    }, 2000);
  }

  get languageOptions() {
    return [
      { value: "en", label: "English", flag: "🇺🇸" },
      { value: "zh-cn", label: "中文", flag: "🇨🇳" },
      { value: "es", label: "Español", flag: "🇪🇸" }
    ];
  }

  get currentLanguageOption() {
    return this.languageOptions.find(opt => opt.value === this.currentLanguage) || this.languageOptions[0];
  }

  @action
  async changeLanguage(language) {
    this.saving = true;
    
    try {
      await ajax("/ai-translator/user-preferred-language", {
        type: "POST",
        data: { language: language, enabled: this.enabled }
      });
      
      this.currentLanguage = language;
      this.showSaved();
      
      // 刷新currentUser数据
      if (this.currentUser) {
        this.currentUser.set("preferred_language", language);
        this.currentUser.set("preferred_language_enabled", this.enabled);
      }
      
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  @action
  async toggleEnabled() {
    this.saving = true;
    
    try {
      const newEnabled = !this.enabled;
      await ajax("/ai-translator/user-preferred-language", {
        type: "POST",
        data: { enabled: newEnabled }
      });
      
      this.enabled = newEnabled;
      this.showSaved();
      
      // 刷新currentUser数据
      if (this.currentUser) {
        this.currentUser.set("preferred_language_enabled", newEnabled);
      }
      
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  willDestroy() {
    super.willDestroy?.();
    if (this.savedNoticeTimerId) {
      clearTimeout(this.savedNoticeTimerId);
      this.savedNoticeTimerId = null;
    }
  }

  <template>
    <div class="control-group ai-translation-language">
      <label class="control-label">
        {{i18n "js.divine_rapier_ai_translator.preferences.ai_translation_language"}}
        <span
          class="text-success"
          style="margin-left: 8px; opacity: {{if this.showSavedNotice '1' '0'}}; transition: opacity 0.6s;"
          aria-live="polite"
        >
          {{i18n "saved"}}
        </span>
      </label>
      
      <!-- Enable/Disable Toggle -->
      <div class="controls">
        <div class="ai-translation-toggle">
          <label class="toggle-label">
            <input
              type="checkbox"
              checked={{this.enabled}}
              disabled={{this.saving}}
              {{on "change" this.toggleEnabled}}
              class="toggle-checkbox"
            />
            <span class="toggle-slider"></span>
            <span class="toggle-text">
              {{i18n "js.divine_rapier_ai_translator.preferences.enable_ai_translation"}}
            </span>
          </label>
        </div>
      </div>
      
      <!-- Language Selection (only show when enabled) -->
      {{#if this.enabled}}
        <div class="controls">
          <div class="language-selection">
            {{#each this.languageOptions as |option|}}
              <button
                type="button"
                class="language-option btn btn-small {{if (eq option.value this.currentLanguage) 'btn-primary selected'}}"
                disabled={{this.saving}}
                {{on "click" (fn this.changeLanguage option.value)}}
                data-language="{{option.value}}"
                data-selected="{{if (eq option.value this.currentLanguage) 'true' 'false'}}"
                aria-pressed="{{if (eq option.value this.currentLanguage) 'true' 'false'}}"
              >
                <span class="flag">{{option.flag}}</span>
                <span class="label">{{option.label}}</span>
              </button>
            {{/each}}
          </div>
        </div>
      {{/if}}
      
      <div class="instructions">
        {{i18n "js.divine_rapier_ai_translator.preferences.ai_translation_language_description"}}
      </div>
    </div>
  </template>
}
