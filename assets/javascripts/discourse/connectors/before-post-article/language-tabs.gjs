import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";

/**
 * Simple language tabs connector component
 * Displays a basic language tabs box before each post
 */
export default class LanguageTabsConnector extends Component {
  // 统一的语言映射
  static languageMap = {
    en: "English",
    "zh-cn": "中文",
    es: "Español",
  };
  @service currentUser;

  @tracked currentLanguage = "original";

  // 获取按钮样式 - 使用箭头函数保持this上下文
  getButtonStyle = (languageCode) => {
    const baseStyle =
      "padding: 4px 16px; border-radius: 3px; cursor: pointer; font-size: 12px; height: 24px; line-height: 1;";

    // 获取翻译状态
    let status = "";
    if (this.post?.post_translations) {
      const translation = this.post.post_translations.find(
        (t) => t.post_translation?.language === languageCode
      );
      status = translation?.post_translation?.status || "";
    }

    if (this.currentLanguage === languageCode) {
      // 当前选中的语言：蓝色背景，白色文字
      return (
        baseStyle +
        " background: #007bff; color: white; border: 1px solid #007bff;"
      );
    } else if (status === "completed") {
      // 完成状态的翻译：白底，蓝字，蓝框
      return (
        baseStyle +
        " background: white; color: #007bff; border: 1px solid #007bff;"
      );
    } else {
      // 其他所有状态：白底，灰字，灰框
      return (
        baseStyle +
        " background: white; color: #6c757d; border: 1px solid #6c757d; cursor: pointer; opacity: 0.8;"
      );
    }
  };

  // 检查语言是否可用
  isLanguageAvailable = (languageCode) => {
    if (languageCode === "original") {
      return true; // 原始内容总是可用的
    }
    const isAvailable = this.availableLanguages.includes(languageCode);
    return isAvailable;
  };

  constructor() {
    super(...arguments);

    // 自动选择用户的偏好语言
    this.initializePreferredLanguage();
  }

  // 检查用户是否禁用了AI翻译功能
  get isAiTranslationDisabled() {
    return this.currentUser?.preferred_language_enabled === false;
  }

  /**
   * 初始化用户的偏好语言选择
   * 如果用户设置了偏好语言且该语言翻译已完成，则自动选择
   * 如果用户禁用了AI翻译功能，则不进行自动选择
   */
  initializePreferredLanguage() {
    // 如果用户禁用了AI翻译功能，直接使用原始内容
    if (this.isAiTranslationDisabled) {
      this.currentLanguage = "original";
      return;
    }

    if (!this.currentUser?.preferred_language) {
      return;
    }

    const preferredLanguage = this.currentUser.preferred_language;

    // 检查偏好语言的翻译状态
    let status = "";
    if (this.post?.post_translations) {
      const translation = this.post.post_translations.find(
        (t) => t.post_translation?.language === preferredLanguage
      );
      status = translation?.post_translation?.status || "";
    }

    // 只有当翻译状态是完成状态时才自动选择
    if (status === "completed") {
      this.currentLanguage = preferredLanguage;
    }
  }

  get post() {
    return this.args.post;
  }

  get availableLanguages() {
    // 从 post_translations 获取已存在的翻译
    let languages = [];
    if (this.post?.post_translations) {
      languages = this.post.post_translations
        .map((t) => {
          return t.post_translation?.language;
        })
        .filter(Boolean);
    }

    return languages;
  }

  get languageNames() {
    // 获取所有支持的语言（包括可用的和不可用的）
    const supportedLanguages = ["en", "zh-cn", "es"];

    const result = supportedLanguages.map((code) => {
      const name = LanguageTabsConnector.languageMap[code] || code;
      const available = this.isLanguageAvailable(code);

      // 获取翻译状态
      let status = "";
      if (this.post?.post_translations) {
        const translation = this.post.post_translations.find(
          (t) => t.post_translation?.language === code
        );
        status = translation?.post_translation?.status || "";
      }

      return {
        code,
        name,
        available,
        status,
        displayText:
          status && status !== "completed" ? `${name} (${status})` : name,
      };
    });

    return result;
  }

  // 获取当前显示的内容（HTML格式）
  get currentContent() {
    if (this.currentLanguage === "original") {
      return this.post?.cooked || this.post?.raw || "";
    }

    // 检查 post_translations 中的翻译
    let translation = null;
    if (this.post?.post_translations) {
      translation = this.post.post_translations.find(
        (t) => t.post_translation?.language === this.currentLanguage
      );
    }

    let translatedContent = "";
    if (translation?.post_translation?.translated_content) {
      translatedContent = translation.post_translation.translated_content;
    }

    if (translatedContent) {
      return translatedContent;
    }

    return this.post?.cooked || "";
  }

  // 获取当前语言名称
  get currentLanguageName() {
    if (this.currentLanguage === "original") {
      return "Raw";
    }

    return (
      LanguageTabsConnector.languageMap[this.currentLanguage] ||
      this.currentLanguage
    );
  }

  // 切换语言的方法
  @action
  async switchLanguage(languageCode) {
    // 如果选择的是原始内容，直接切换
    if (languageCode === "original") {
      this.currentLanguage = languageCode;
      return;
    }

    // 获取翻译状态
    let status = "";
    if (this.post?.post_translations) {
      const translation = this.post.post_translations.find(
        (t) => t.post_translation?.language === languageCode
      );
      status = translation?.post_translation?.status || "";
    }

    // 如果翻译状态是完成状态，可以切换
    if (status === "completed") {
      this.currentLanguage = languageCode;
      return;
    }

    // 如果翻译状态不是完成状态，选择Raw
    this.currentLanguage = "original";
  }

  // 新增：获取语言名称的辅助方法
  getLanguageName(languageCode) {
    return LanguageTabsConnector.languageMap[languageCode] || languageCode;
  }

  <template>
    {{! 只有在用户启用AI翻译功能时才显示语言切换标签 }}
    {{#if this.isAiTranslationDisabled}}
      <div
        style="font-size: 10px; color: #999; margin-bottom: 5px; margin-left: 12px;"
      >
        AI Translation is disabled by user
      </div>
    {{else}}
      <div
        style="display: flex; gap: 3px; flex-wrap: wrap; margin-bottom: 8px; margin-left: 12px;"
      >
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
            title={{if
              langInfo.available
              "Switch to {{langInfo.name}}"
              "Click to start translation for {{langInfo.name}}"
            }}
          >
            {{langInfo.displayText}}
          </button>
        {{/each}}
      </div>
    {{/if}}

    {{! 替换原post内容，直接显示当前选中的内容 }}
    <div class="cooked">
      {{htmlSafe this.currentContent}}
    </div>
  </template>
}
