import Service from "@ember/service";
import { service } from "@ember/service";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";

/**
 * Translation Status Service for handling real-time translation status updates
 */
@disableImplicitInjections
export default class TranslationStatusService extends Service {
  @service messageBus;
  @service appEvents;
  
  // 存储每个帖子的翻译状态
  translationStates = new Map();
  
  // 订阅话题的翻译状态更新
  subscribeToTopic(topicId) {
    const channel = `/ai-translator/topic/${topicId}`;
    
    console.log(`📡 MessageBus: Subscribing to topic channel ${channel} for topic ${topicId}`);
    
    this.messageBus.subscribe(channel, (data) => {
      console.log(`📡 MessageBus: Received message on topic channel ${channel}:`, data);
      this.handleTranslationUpdate(data.post_id, data);
    });
  }
  
  // 订阅帖子的翻译状态更新（保持向后兼容）
  subscribeToPost(postId) {
    // 这个方法现在被弃用，建议使用 subscribeToTopic
    console.warn(`⚠️ subscribeToPost is deprecated, use subscribeToTopic instead for post ${postId}`);
    // 为了向后兼容，暂时保留但不再使用
  }
  
  // 处理翻译状态更新
  handleTranslationUpdate(postId, data) {
    const { target_language, status, error, translation_id, translated_content } = data;
    
    console.log(`🔄 Translation status update for post ${postId}, language ${target_language}, status: ${status}`);
    
    // 更新状态
    if (!this.translationStates.has(postId)) {
      this.translationStates.set(postId, new Map());
    }
    
    const postStates = this.translationStates.get(postId);
    postStates.set(target_language, {
      status,
      error,
      translation_id,
      translated_content,
      timestamp: data.timestamp
    });
    
    // 触发事件通知组件
    this.appEvents.trigger("translation:status-changed", {
      postId,
      targetLanguage: target_language,
      status,
      error,
      translationId: translation_id,
      translatedContent: translated_content
    });
    
    console.log(`📢 Triggered translation:status-changed event for post ${postId}`);
    
    // 显示用户通知
    this.showUserNotification(target_language, status, error);
  }
  
  // 显示用户通知
  showUserNotification(targetLanguage, status, error) {
    const languageNames = {
      en: "English",
      zh: "中文",
      es: "Español"
    };
    
    const languageName = languageNames[targetLanguage] || targetLanguage;
    
    switch (status) {
      case "started":
        this.appEvents.trigger("modal:alert", {
          message: `Translation started for ${languageName}...`,
          type: "info"
        });
        break;
      case "completed":
        this.appEvents.trigger("modal:alert", {
          message: `Translation completed for ${languageName}!`,
          type: "success"
        });
        break;
      case "failed":
        this.appEvents.trigger("modal:alert", {
          message: `Translation failed for ${languageName}: ${error}`,
          type: "error"
        });
        break;
    }
  }
  
  // 获取帖子的翻译状态
  getTranslationStatus(postId, targetLanguage) {
    const postStates = this.translationStates.get(postId);
    return postStates?.get(targetLanguage) || { status: "idle" };
  }
  
  // 检查是否有正在进行的翻译
  hasPendingTranslation(postId, targetLanguage) {
    const status = this.getTranslationStatus(postId, targetLanguage);
    return status.status === "started";
  }
  
  // 取消订阅话题
  unsubscribeFromTopic(topicId) {
    const channel = `/ai-translator/topic/${topicId}`;
    this.messageBus.unsubscribe(channel);
    console.log(`📡 MessageBus: Unsubscribed from topic channel ${channel}`);
  }
  
  // 取消订阅帖子（保持向后兼容）
  unsubscribeFromPost(postId) {
    // 这个方法现在被弃用，建议使用 unsubscribeFromTopic
    console.warn(`⚠️ unsubscribeFromPost is deprecated, use unsubscribeFromTopic instead for post ${postId}`);
    // 为了向后兼容，暂时保留但不再使用
  }
}
