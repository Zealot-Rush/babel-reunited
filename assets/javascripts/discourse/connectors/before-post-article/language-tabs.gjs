import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { service } from "@ember/service";

/**
 * Simple language tabs connector component
 * Displays a basic language tabs box before each post
 */
export default class LanguageTabsConnector extends Component {
  @tracked currentLanguage = "original";
  @service currentUser;

  // 获取按钮样式 - 使用箭头函数保持this上下文
  getButtonStyle = (languageCode) => {
    const baseStyle =
      "padding: 4px 16px; border-radius: 3px; cursor: pointer; font-size: 12px; height: 24px; line-height: 1;";

    if (this.currentLanguage === languageCode) {
      return baseStyle + " background: #007bff; color: white; border: none;";
    } else {
      return (
        baseStyle +
        " background: #f8f9fa; color: #007bff; border: 1px solid #007bff;"
      );
    }
  };

  constructor() {
    super(...arguments);
    console.log("🔍 DEBUG: currentUser:", this.currentUser);
    console.log("🚀 LanguageTabsConnector constructor called!");
    console.log("📋 Available args:", this.args);
    console.log("🔍 DEBUG: enabled:", this.enabled);
    console.log("🔍 DEBUG: language:", this.language);
    
    // 自动选择用户的偏好语言
    this.initializePreferredLanguage();
  }

  /**
   * 初始化用户的偏好语言选择
   * 如果用户设置了偏好语言且该语言在可用翻译中，则自动选择
   */
  initializePreferredLanguage() {
    console.log("🔍 DEBUG: initializePreferredLanguage called");
    console.log("🔍 DEBUG: currentUser:", this.currentUser);
    console.log("🔍 DEBUG: preferred_language:", this.currentUser?.preferred_language);
    console.log("🔍 DEBUG: preferred_language_enabled:", this.currentUser?.preferred_language_enabled);
    
    if (!this.currentUser?.preferred_language) {
      console.log("🔍 DEBUG: No user preferred language set, using original");
      return;
    }

    const preferredLanguage = this.currentUser.preferred_language;
    console.log("🔍 DEBUG: User preferred language:", preferredLanguage);
    
    // 检查偏好语言是否在可用翻译中
    const availableLanguages = this.availableLanguages;
    console.log("🔍 DEBUG: Available languages:", availableLanguages);
    console.log("🔍 DEBUG: Does availableLanguages include preferred language?", availableLanguages.includes(preferredLanguage));
    
    if (availableLanguages.includes(preferredLanguage)) {
      console.log("✅ Auto-selecting user preferred language:", preferredLanguage);
      this.currentLanguage = preferredLanguage;
    } else {
      console.log("⚠️ User preferred language not available in translations, using original");
      console.log("🔍 DEBUG: Preferred language:", preferredLanguage);
      console.log("🔍 DEBUG: Available languages:", availableLanguages);
    }
  }

  get post() {
    return this.args.post;
  }

  get availableLanguages() {
    console.log("🔍 DEBUG: Getting availableLanguages");
    console.log("🔍 DEBUG: post:", this.post);
    console.log("🔍 DEBUG: post_translations:", this.post?.post_translations);
    
    if (!this.post?.post_translations) {
      console.log("🔍 DEBUG: No post_translations found");
      return [];
    }
    
    const languages = this.post.post_translations.map((t, index) => {
      console.log(`🔍 DEBUG: Translation ${index}:`, t);
      console.log(`🔍 DEBUG: Translation ${index} post_translation:`, t.post_translation);
      console.log(`🔍 DEBUG: Translation ${index} language:`, t.post_translation?.language);
      return t.post_translation?.language;
    }).filter(Boolean);
    
    console.log("🔍 DEBUG: Final availableLanguages:", languages);
    return languages;
  }

  get languageNames() {
    const languageMap = {
      en: "English",
      zh: "中文",
      es: "Español",
      fr: "Français",
      de: "Deutsch",
      ja: "日本語",
      ko: "한국어",
      ru: "Русский",
      ar: "العربية",
      pt: "Português",
      it: "Italiano",
      nl: "Nederlands",
    };

    return (
      this.post?.post_translations?.map((t) => ({
        code: t.post_translation?.language,
        name:
          languageMap[t.post_translation?.language] ||
          t.post_translation?.language,
      })) || []
    );
  }

  // 获取当前显示的内容（HTML格式）
  get currentContent() {
    if (this.currentLanguage === "original") {
      return this.post?.cooked || this.post?.raw || "";
    }

    const translation = this.post?.post_translations?.find(
      (t) => t.post_translation?.language === this.currentLanguage
    );

    const translatedContent = translation?.post_translation?.translated_content || "";
    
    // 将换行符转换为HTML换行标签
    if (translatedContent) {
      return translatedContent
        .replace(/\n\n/g, '<br><br>')  // 先处理双换行（段落分隔）
        .replace(/\n/g, '<br>');      // 再处理单换行
    }

    return this.post?.cooked || "";
  }

  // 获取当前语言名称
  get currentLanguageName() {
    if (this.currentLanguage === "original") {
      return "Raw";
    }

    const languageMap = {
      en: "English",
      zh: "中文",
      es: "Español",
      fr: "Français",
      de: "Deutsch",
      ja: "日本語",
      ko: "한국어",
      ru: "Русский",
      ar: "العربية",
      pt: "Português",
      it: "Italiano",
      nl: "Nederlands",
    };

    return languageMap[this.currentLanguage] || this.currentLanguage;
  }

  // 切换语言的方法
  @action
  switchLanguage(languageCode) {
    // eslint-disable-next-line no-console
    console.log("🔄 Switching language to:", languageCode);
    this.currentLanguage = languageCode;
  }

  <template>
    {{! 语言切换标签 }}
    <div style="display: flex; gap: 3px; flex-wrap: wrap; margin-bottom: 8px; margin-left: 12px;">
      <button
        style={{this.getButtonStyle "original"}}
        {{on "click" (fn this.switchLanguage "original")}}
      >
        Raw
      </button>

      {{#each this.languageNames as |langInfo|}}
        <button
          style={{this.getButtonStyle langInfo.code}}
          {{on "click" (fn this.switchLanguage langInfo.code)}}
        >
          {{langInfo.name}}
        </button>
      {{/each}}
    </div>

    {{! 替换原post内容，直接显示当前选中的内容 }}
    <div class="cooked">
      {{htmlSafe this.currentContent}}
    </div>
  </template>
}
