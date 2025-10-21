# frozen_string_literal: true

class Jobs::DivineRapierAiTranslator::TranslatePostJob < ::Jobs::Base
  def execute(args)
    post_id = args[:post_id]
    target_language = args[:target_language]
    force_update = args[:force_update] || false
    start_time = Time.current

    return if post_id.blank? || target_language.blank?

    post = Post.find_by(id: post_id)
    if post.blank?
      # 发布失败通知
      publish_translation_status(post_id, target_language, "failed", "post_not_found")
      DivineRapierAiTranslator::TranslationLogger.log_translation_skipped(
        post_id: post_id,
        target_language: target_language,
        reason: "post_not_found",
      )
      return
    end

    # Skip if post is deleted or not visible
    if post.deleted_at.present? || post.hidden?
      publish_translation_status(post_id, target_language, "failed", "post_deleted_or_hidden", post.topic_id)
      DivineRapierAiTranslator::TranslationLogger.log_translation_skipped(
        post_id: post_id,
        target_language: target_language,
        reason: "post_deleted_or_hidden",
      )
      return
    end

    # Check if translation already exists (unless force update)
    existing_translation =
      DivineRapierAiTranslator::PostTranslation.find_translation(post_id, target_language)
    if existing_translation.present? && !force_update
      DivineRapierAiTranslator::TranslationLogger.log_translation_skipped(
        post_id: post_id,
        target_language: target_language,
        reason: "translation_already_exists",
      )
      return
    end

    # 发布开始通知
    publish_translation_status(post_id, target_language, "started", nil, post.topic_id)

    # Log translation start
    DivineRapierAiTranslator::TranslationLogger.log_translation_start(
      post_id: post_id,
      target_language: target_language,
      content_length: post.raw&.length || 0,
      force_update: force_update,
    )

    # Perform translation
    result =
      DivineRapierAiTranslator::TranslationService.new(
        post: post,
        target_language: target_language,
        force_update: force_update,
      ).call

    processing_time = ((Time.current - start_time) * 1000).round(2)

    if result.failure?
      # 发布失败通知
      publish_translation_status(post_id, target_language, "failed", result.error, post.topic_id)
      DivineRapierAiTranslator::TranslationLogger.log_translation_error(
        post_id: post_id,
        target_language: target_language,
        error: StandardError.new(result.error),
        processing_time: processing_time,
      )
      Rails.logger.error("Translation failed for post #{post_id}: #{result.error}")
    else
      # 发布成功通知
      translation = result.translation
      publish_translation_status(
        post_id, 
        target_language, 
        "completed", 
        nil, 
        post.topic_id,
        translation&.id,
        translation&.translated_content
      )
      
      # Log successful translation
      ai_response = result.ai_response || {}
      DivineRapierAiTranslator::TranslationLogger.log_translation_success(
        post_id: post_id,
        target_language: target_language,
        translation_id: translation&.id,
        ai_response: ai_response,
        processing_time: processing_time,
        force_update: force_update,
      )
    end
  end

  private

  def publish_translation_status(post_id, target_language, status, error = nil, topic_id = nil, translation_id = nil, translated_content = nil)
    payload = {
      post_id: post_id,
      target_language: target_language,
      status: status,
      timestamp: Time.current.iso8601
    }
    
    payload[:error] = error if error
    payload[:translation_id] = translation_id if translation_id
    payload[:translated_content] = translated_content if translated_content

    # 发布到话题级别的频道
    if topic_id
      channel = "/ai-translator/topic/#{topic_id}"
      user_ids = Post.find(post_id).topic.allowed_user_ids
      
      Rails.logger.info("📡 MessageBus: Publishing to topic channel #{channel} with payload: #{payload.inspect}")
      Rails.logger.info("📡 MessageBus: Target user IDs: #{user_ids.inspect}")
      
      MessageBus.publish(channel, payload, user_ids: user_ids)
      
      Rails.logger.info("📡 MessageBus: Published successfully to topic channel")
    else
      Rails.logger.warn("📡 MessageBus: No topic_id provided, skipping publish")
    end
  end
end
