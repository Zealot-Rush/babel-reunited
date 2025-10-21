# frozen_string_literal: true

class Jobs::DivineRapierAiTranslator::TranslatePostJob < ::Jobs::Base
  def execute(args)
    post_id = args[:post_id]
    target_language = args[:target_language]
    force_update = args[:force_update] || false
    start_time = Time.current

    return unless validate_arguments(post_id, target_language)

    post = find_and_validate_post(post_id, target_language)
    return unless post

    # Create or update translation record with "translating" status
    translation = create_or_update_translation_record(post, target_language)
    
    notify_translation_started(post_id, target_language, post.topic_id, translation.id)
    log_translation_start(post_id, target_language, post, force_update)

    result = execute_translation_service(post, target_language, force_update)
    processing_time = calculate_processing_time(start_time)

    handle_translation_result(result, post_id, target_language, post.topic_id, processing_time, force_update, translation)
  rescue => e
    # Handle any unexpected exceptions during translation
    processing_time = calculate_processing_time(start_time)
    handle_unexpected_error(e, post_id, target_language, processing_time)
  end

  private

  def validate_arguments(post_id, target_language)
    return false if post_id.blank? || target_language.blank?
    true
  end

  def find_and_validate_post(post_id, target_language)
    post = Post.find_by(id: post_id)
    
    if post.blank?
      handle_post_not_found(post_id, target_language)
      return nil
    end

    if post.deleted_at.present? || post.hidden?
      handle_post_deleted_or_hidden(post_id, target_language, post.topic_id)
      return nil
    end

    post
  end

  def create_or_update_translation_record(post, target_language)
    existing_translation = DivineRapierAiTranslator::PostTranslation.find_translation(post.id, target_language)
    
    if existing_translation.present?
      # Update existing translation with "translating" status and empty content
      existing_translation.update!(
        status: "translating",
        translated_content: "",
        translated_title: "",
        metadata: existing_translation.metadata.merge(
          translating_started_at: Time.current,
          updated_at: Time.current,
        ),
      )
      existing_translation
    else
      # Create new translation with "translating" status and empty content
      DivineRapierAiTranslator::PostTranslation.create!(
        post: post,
        language: target_language,
        status: "translating",
        translated_content: "",
        translated_title: "",
        translation_provider: "openai",
        metadata: {
          translating_started_at: Time.current,
        },
      )
    end
  end

  def handle_post_not_found(post_id, target_language)
    publish_translation_status(post_id, target_language, "failed", "post_not_found")
    DivineRapierAiTranslator::TranslationLogger.log_translation_skipped(
      post_id: post_id,
      target_language: target_language,
      reason: "post_not_found",
    )
  end

  def handle_post_deleted_or_hidden(post_id, target_language, topic_id)
    publish_translation_status(post_id, target_language, "failed", "post_deleted_or_hidden", topic_id)
    DivineRapierAiTranslator::TranslationLogger.log_translation_skipped(
      post_id: post_id,
      target_language: target_language,
      reason: "post_deleted_or_hidden",
    )
  end

  def notify_translation_started(post_id, target_language, topic_id, translation_id)
    publish_translation_status(post_id, target_language, "started", nil, topic_id, translation_id)
  end

  def log_translation_start(post_id, target_language, post, force_update)
    DivineRapierAiTranslator::TranslationLogger.log_translation_start(
      post_id: post_id,
      target_language: target_language,
      content_length: post.raw&.length || 0,
      force_update: force_update,
    )
  end

  def execute_translation_service(post, target_language, force_update)
    DivineRapierAiTranslator::TranslationService.new(
      post: post,
      target_language: target_language,
      force_update: force_update,
    ).call
  end

  def calculate_processing_time(start_time)
    ((Time.current - start_time) * 1000).round(2)
  end

  def handle_translation_result(result, post_id, target_language, topic_id, processing_time, force_update, translation)
    if result.failure?
      handle_translation_failure(result, post_id, target_language, topic_id, processing_time, translation)
    else
      handle_translation_success(result, post_id, target_language, topic_id, processing_time, force_update, translation)
    end
  end

  def handle_translation_failure(result, post_id, target_language, topic_id, processing_time, translation)
    # Update translation status to failed
    translation.update!(
      status: "failed",
      metadata: translation.metadata.merge(
        error: result.error,
        failed_at: Time.current,
      ),
    )
    
    publish_translation_status(post_id, target_language, "failed", result.error, topic_id, translation.id)
    DivineRapierAiTranslator::TranslationLogger.log_translation_error(
      post_id: post_id,
      target_language: target_language,
      error: StandardError.new(result.error),
      processing_time: processing_time,
    )
    Rails.logger.error("Translation failed for post #{post_id}: #{result.error}")
  end

  def handle_translation_success(result, post_id, target_language, topic_id, processing_time, force_update, translation)
    # Update translation with actual translated content and completed status
    translation.update!(
      status: "completed",
      translated_content: result.translation.translated_content,
      translated_title: result.translation.translated_title,
      source_language: result.translation.source_language,
      metadata: translation.metadata.merge(
        confidence: result.ai_response[:confidence],
        provider_info: result.ai_response[:provider_info],
        translated_at: Time.current,
        completed_at: Time.current,
      ),
    )
    
    publish_translation_status(
      post_id, 
      target_language, 
      "completed", 
      nil, 
      topic_id,
      translation.id,
      translation.translated_content
    )
    
    ai_response = result.ai_response || {}
    DivineRapierAiTranslator::TranslationLogger.log_translation_success(
      post_id: post_id,
      target_language: target_language,
      translation_id: translation.id,
      ai_response: ai_response,
      processing_time: processing_time,
      force_update: force_update,
    )
  end

  def handle_unexpected_error(error, post_id, target_language, processing_time)
    # Try to find the translation record to update its status
    translation = DivineRapierAiTranslator::PostTranslation.find_translation(post_id, target_language)
    
    if translation.present?
      translation.update!(
        status: "failed",
        metadata: translation.metadata.merge(
          error: error.message,
          error_class: error.class.name,
          failed_at: Time.current,
        ),
      )
      
      publish_translation_status(post_id, target_language, "failed", error.message, translation.post.topic_id, translation.id)
    else
      # If no translation record exists, just publish the status
      publish_translation_status(post_id, target_language, "failed", error.message)
    end
    
    # Log the error
    DivineRapierAiTranslator::TranslationLogger.log_translation_error(
      post_id: post_id,
      target_language: target_language,
      error: error,
      processing_time: processing_time,
    )
    
    Rails.logger.error("Unexpected error in translation job for post #{post_id}: #{error.message}")
    Rails.logger.error(error.backtrace.join("\n")) if error.backtrace
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
      
      # Safely get user IDs, handle case where post might not exist
      begin
        post = Post.find(post_id)
        user_ids = post.topic.allowed_user_ids
      rescue ActiveRecord::RecordNotFound
        Rails.logger.warn("📡 MessageBus: Post #{post_id} not found, skipping publish")
        return
      end
      
      Rails.logger.info("📡 MessageBus: Publishing to topic channel #{channel} with payload: #{payload.inspect}")
      Rails.logger.info("📡 MessageBus: Target user IDs: #{user_ids.inspect}")
      
      MessageBus.publish(channel, payload, user_ids: user_ids)
      
      Rails.logger.info("📡 MessageBus: Published successfully to topic channel")
    else
      Rails.logger.warn("📡 MessageBus: No topic_id provided, skipping publish")
    end
  end
end
