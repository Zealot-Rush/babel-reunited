# frozen_string_literal: true

class DivineRapierAiTranslatorTranslatePostJob < ::Jobs::Base
  def execute(args)
    post_id = args[:post_id]
    target_language = args[:target_language]
    start_time = Time.current

    return if post_id.blank? || target_language.blank?

    post = Post.find_by(id: post_id)
    if post.blank?
      DivineRapierAiTranslator::TranslationLogger.log_translation_skipped(
        post_id: post_id,
        target_language: target_language,
        reason: "post_not_found"
      )
      return
    end

    # Skip if post is deleted or not visible
    if post.deleted_at.present? || post.hidden?
      DivineRapierAiTranslator::TranslationLogger.log_translation_skipped(
        post_id: post_id,
        target_language: target_language,
        reason: "post_deleted_or_hidden"
      )
      return
    end

    # Check if translation already exists
    existing_translation = DivineRapierAiTranslator::PostTranslation.find_translation(post_id, target_language)
    if existing_translation.present?
      DivineRapierAiTranslator::TranslationLogger.log_translation_skipped(
        post_id: post_id,
        target_language: target_language,
        reason: "translation_already_exists"
      )
      return
    end

    # Log translation start
    DivineRapierAiTranslator::TranslationLogger.log_translation_start(
      post_id: post_id,
      target_language: target_language,
      content_length: post.raw&.length || 0
    )

    # Perform translation
    result = DivineRapierAiTranslator::TranslationService.new(
      post: post,
      target_language: target_language
    ).call

    processing_time = ((Time.current - start_time) * 1000).round(2)

    if result.failure?
      DivineRapierAiTranslator::TranslationLogger.log_translation_error(
        post_id: post_id,
        target_language: target_language,
        error: StandardError.new(result.error),
        processing_time: processing_time
      )
      Rails.logger.error("Translation failed for post #{post_id}: #{result.error}")
    else
      # Log successful translation
      translation = result.translation
      ai_response = result.ai_response || {}
      
      DivineRapierAiTranslator::TranslationLogger.log_translation_success(
        post_id: post_id,
        target_language: target_language,
        translation_id: translation&.id,
        ai_response: ai_response,
        processing_time: processing_time
      )
    end
  end
end
