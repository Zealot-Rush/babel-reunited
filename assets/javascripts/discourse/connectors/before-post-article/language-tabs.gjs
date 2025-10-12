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
  }

  get post() {
    return this.args.post;
  }

  get availableLanguages() {
    const languages =
      this.post?.post_translations?.map((t) => t.post_translation?.language) ||
      [];
    // eslint-disable-next-line no-console
    console.log("🔍 DEBUG: availableLanguages:", languages);
    // eslint-disable-next-line no-console
    console.log("🔍 DEBUG: post_translations:", this.post?.post_translations);
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
