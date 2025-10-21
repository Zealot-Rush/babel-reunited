import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { service } from "@ember/service";
import { get } from "@ember/object";
import { eq } from "truth-helpers";

/**
 * Simple language tabs connector component
 * Displays a basic language tabs box before each post
 */
export default class LanguageTabsConnector extends Component {
  @tracked currentLanguage = "original";
  @service currentUser;
  @service translationApi; // 添加翻译API服务
  @service appEvents; // 添加应用事件服务
  @service translationStatus; // 新增翻译状态服务
  
  // 存储翻译状态
  @tracked translationStates = new Map();
  @tracked refreshTrigger = 0;
  @tracked contentRefreshScheduled = false; // 用于强制重新计算 availableLanguages

  // 检查用户是否禁用了AI翻译功能
  get isAiTranslationDisabled() {
    return this.currentUser?.preferred_language_enabled === false;
  }

  // 获取按钮样式 - 使用箭头函数保持this上下文
  getButtonStyle = (languageCode) => {
    // 使用 refreshTrigger 来强制重新计算
    this.refreshTrigger; // 这会触发重新计算当 refreshTrigger 改变时
    
    const baseStyle =
      "padding: 4px 16px; border-radius: 3px; cursor: pointer; font-size: 12px; height: 24px; line-height: 1;";

    // 检查语言是否可用
    const isAvailable = this.isLanguageAvailable(languageCode);
    const translationStatus = this.translationStates.get(languageCode);
    const isTranslating = translationStatus?.status === "started";


    if (this.currentLanguage === languageCode) {
      return baseStyle + " background: #007bff; color: white; border: none;";
    } else if (isAvailable) {
      return (
        baseStyle +
        " background: #f8f9fa; color: #007bff; border: 1px solid #007bff;"
      );
    } else if (isTranslating) {
      // 翻译中的样式
      return (
        baseStyle +
        " background: #fff3cd; color: #856404; border: 1px solid #ffeaa7; animation: pulse 1.5s infinite;"
      );
    } else {
      // 不可用时的样式 - 改为看起来可点击的样式
      return (
        baseStyle +
        " background: #f8f9fa; color: #6c757d; border: 1px solid #6c757d; cursor: pointer; opacity: 0.8;"
      );
    }
  };

  // 检查语言是否可用
  isLanguageAvailable = (languageCode) => {
    // 使用 refreshTrigger 来强制重新计算
    this.refreshTrigger; // 这会触发重新计算当 refreshTrigger 改变时
    
    if (languageCode === "original") {
      return true; // 原始内容总是可用的
    }
    const isAvailable = this.availableLanguages.includes(languageCode);
    return isAvailable;
  };

  constructor() {
    super(...arguments);
    
    // 订阅翻译状态更新
    this.appEvents.on("translation:status-changed", this.handleTranslationStatusChange);
    
    // 订阅当前话题的翻译状态
    if (this.post?.topic_id) {
      this.translationStatus.subscribeToTopic(this.post.topic_id);
    }
    
    // 自动选择用户的偏好语言
    this.initializePreferredLanguage();
  }

  willDestroy() {
    super.willDestroy();
    this.appEvents.off("translation:status-changed", this.handleTranslationStatusChange);
    if (this.post?.topic_id) {
      this.translationStatus.unsubscribeFromTopic(this.post.topic_id);
    }
  }

  // 处理翻译状态变化
  @action
  handleTranslationStatusChange(data) {
    if (data.postId === this.post?.id) {
      // 创建新的Map来触发重新渲染
      const newTranslationStates = new Map(this.translationStates);
      newTranslationStates.set(data.targetLanguage, {
        status: data.status,
        error: data.error,
        translationId: data.translationId,
        translatedContent: data.translatedContent
      });
      this.translationStates = newTranslationStates;
      
      // 强制触发UI更新
      this.refreshTrigger++;
      
      // 如果翻译完成，刷新可用语言列表和翻译内容
      if (data.status === "completed") {
        this.refreshAvailableLanguages();
        // 立即刷新翻译内容
        this.refreshPostTranslations();
      }
    } else {
      // 显示其他post的更新通知
      this.showOtherPostUpdateNotification(data.postId, data.targetLanguage, data.status);
    }
  }

  // 刷新可用语言列表
  async refreshAvailableLanguages() {
    try {
      const status = await this.translationApi.getTranslationStatus(this.post.id);
      
      // 触发重新计算 availableLanguages
      this.refreshTrigger++;
    } catch (error) {
      // Failed to refresh available languages
    }
  }

  // 调度内容刷新
  scheduleContentRefresh() {
    if (this.contentRefreshScheduled) {
      return; // 防止重复调度
    }
    
    this.contentRefreshScheduled = true;
    
    // 延迟刷新，给后端时间保存翻译
    setTimeout(async () => {
      try {
        await this.refreshPostTranslations();
      } catch (error) {
        // Failed to refresh post translations
      } finally {
        this.contentRefreshScheduled = false; // 重置标志
      }
    }, 1000); // 1秒延迟
  }

  // 刷新帖子的翻译数据
  async refreshPostTranslations() {
    try {
      const translations = await this.translationApi.getTranslations(this.post.id);
      
      // 更新 post 的 post_translations
      if (this.post && translations) {
        this.post.post_translations = translations;
      }
      
      // 触发重新计算
      this.refreshTrigger++;
    } catch (error) {
      // Failed to refresh post translations
    }
  }

  // 显示其他post的更新通知
  showOtherPostUpdateNotification(postId, targetLanguage, status) {
    const languageNames = {
      en: "English",
      zh: "中文", 
      es: "Español"
    };
    
    const languageName = languageNames[targetLanguage] || targetLanguage;
    
    if (status === "completed") {
      // 显示翻译完成通知
      this.appEvents.trigger("notify:info", {
        message: `Post #${postId} has been translated to ${languageName}. Please refresh to see the translation.`,
        duration: 5000
      });
    } else if (status === "started") {
      // 显示翻译开始通知
      this.appEvents.trigger("notify:info", {
        message: `Post #${postId} is being translated to ${languageName}...`,
        duration: 3000
      });
    } else if (status === "failed") {
      // 显示翻译失败通知
      this.appEvents.trigger("notify:error", {
        message: `Translation of Post #${postId} to ${languageName} failed.`,
        duration: 5000
      });
    }
  }

  /**
   * 初始化用户的偏好语言选择
   * 如果用户设置了偏好语言且该语言在可用翻译中，则自动选择
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
    
    // 检查偏好语言是否在可用翻译中
    const availableLanguages = this.availableLanguages;
    
    if (availableLanguages.includes(preferredLanguage)) {
      this.currentLanguage = preferredLanguage;
    }
  }

  get post() {
    return this.args.post;
  }

  get availableLanguages() {
    // 使用 refreshTrigger 来强制重新计算
    this.refreshTrigger; // 这会触发重新计算当 refreshTrigger 改变时
    
    // 从 post_translations 获取已存在的翻译
    let languages = [];
    if (this.post?.post_translations) {
      languages = this.post.post_translations.map((t) => {
        return t.post_translation?.language;
      }).filter(Boolean);
    }
    
    // 从 translationStates 获取已完成的翻译
    const completedTranslations = [];
    for (const [language, state] of this.translationStates) {
      if (state.status === "completed") {
        completedTranslations.push(language);
      }
    }
    
    // 合并两个来源的语言列表
    const allLanguages = [...new Set([...languages, ...completedTranslations])];
    
    return allLanguages;
  }

  get languageNames() {
    // 使用 refreshTrigger 来强制重新计算
    this.refreshTrigger; // 这会触发重新计算当 refreshTrigger 改变时
    
    const languageMap = {
      en: "English",
      zh: "中文",
      es: "Español",
    };

    // 获取所有支持的语言（包括可用的和不可用的）
    const supportedLanguages = ["en", "zh", "es"];
    
    const result = supportedLanguages.map(code => ({
      code: code,
      name: languageMap[code] || code,
      available: this.isLanguageAvailable(code)
    }));
    
    return result;
  }

  // 获取当前显示的内容（HTML格式）
  get currentContent() {
    // 使用 refreshTrigger 来强制重新计算
    this.refreshTrigger; // 这会触发重新计算当 refreshTrigger 改变时
    
    if (this.currentLanguage === "original") {
      return this.post?.cooked || this.post?.raw || "";
    }

    // 首先检查 post_translations 中的翻译
    let translation = null;
    if (this.post?.post_translations) {
      translation = this.post.post_translations.find(
        (t) => t.post_translation?.language === this.currentLanguage
      );
    }

    let translatedContent = "";
    if (translation?.post_translation?.translated_content) {
      translatedContent = translation.post_translation.translated_content;
    } else {
      // 如果 post_translations 中没有，检查 translationStates 中是否有已完成的翻译
      const translationState = this.translationStates.get(this.currentLanguage);
      if (translationState?.status === "completed") {
        if (translationState?.translatedContent) {
          translatedContent = translationState.translatedContent;
        } else {
          // 调度内容刷新作为后备方案（防止重复调度）
          if (!this.contentRefreshScheduled) {
            this.scheduleContentRefresh();
          }
        }
      }
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

    const languageMap = {
      en: "English",
      zh: "中文",
      es: "Español",
    };

    return languageMap[this.currentLanguage] || this.currentLanguage;
  }

  // 切换语言的方法
  @action
  async switchLanguage(languageCode) {
    // 如果语言可用，直接切换
    if (this.isLanguageAvailable(languageCode)) {
      this.currentLanguage = languageCode;
      return;
    }
    
    // 如果语言不可用且不是原始语言，触发翻译任务
    if (languageCode !== "original") {
      await this.triggerTranslation(languageCode);
    }
  }

  // 新增：触发翻译任务的方法
  @action
  async triggerTranslation(languageCode) {
    try {
      // 显示加载状态
      this.appEvents?.trigger("modal:alert", {
        message: `Starting translation for ${this.getLanguageName(languageCode)}...`,
        type: "info"
      });
      
      // 调用翻译API
      const result = await this.translationApi.createTranslation(
        this.post.id, 
        languageCode
      );
      
      // 显示成功消息
      this.appEvents?.trigger("modal:alert", {
        message: `Translation started for ${this.getLanguageName(languageCode)}. It will be available shortly.`,
        type: "success"
      });
      
    } catch (error) {
      this.appEvents?.trigger("modal:alert", {
        message: `Failed to start translation: ${error.message}`,
        type: "error"
      });
    }
  }

  // 新增：获取语言名称的辅助方法
  getLanguageName(languageCode) {
    const languageMap = {
      en: "English",
      zh: "中文", 
      es: "Español",
    };
    return languageMap[languageCode] || languageCode;
  }

  <template>
    {{! 只有在用户启用AI翻译功能时才显示语言切换标签 }}
    {{#unless this.isAiTranslationDisabled}}
      <div style="display: flex; gap: 3px; flex-wrap: wrap; margin-bottom: 8px; margin-left: 12px;">
        <button
          style={{this.getButtonStyle "original"}}
          {{on "click" (fn this.switchLanguage "original")}}
        >
          Raw
        </button>

        {{#each this.languageNames as |langInfo|}}
          {{#let (get this.translationStates langInfo.code) as |translationState|}}
            <button
              style={{this.getButtonStyle langInfo.code}}
              {{on "click" (fn this.switchLanguage langInfo.code)}}
              title={{if langInfo.available 
                "Switch to {{langInfo.name}}" 
                (if (eq translationState.status "started")
                  "Translating {{langInfo.name}}..."
                  "Click to start translation for {{langInfo.name}}"
                )
              }}
            >
              {{langInfo.name}}
              {{#unless langInfo.available}}
                {{#if (eq translationState.status "started")}}
                  <span style="font-size: 10px; margin-left: 4px;">(Translating...)</span>
                {{else}}
                  <span style="font-size: 10px; margin-left: 4px;">(Click to translate)</span>
                {{/if}}
              {{/unless}}
            </button>
          {{/let}}
        {{/each}}
      </div>
    {{else}}
      <div style="font-size: 10px; color: #999; margin-bottom: 5px; margin-left: 12px;">
        AI Translation is disabled by user
      </div>
    {{/unless}}

    {{! 替换原post内容，直接显示当前选中的内容 }}
    <div class="cooked">
      {{htmlSafe this.currentContent}}
    </div>
  </template>
}
