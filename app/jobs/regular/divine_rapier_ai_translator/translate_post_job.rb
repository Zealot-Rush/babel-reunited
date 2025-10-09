# frozen_string_literal: true

module DivineRapierAiTranslator
  class TranslatePostJob < ::Jobs::Base
    def execute(args)
      post_id = args[:post_id]
      target_language = args[:target_language]

      return if post_id.blank? || target_language.blank?

      post = Post.find_by(id: post_id)
      return if post.blank?

      # Skip if post is deleted or not visible
      return if post.deleted_at.present? || post.hidden?

      # Check if translation already exists
      existing_translation = PostTranslation.find_translation(post_id, target_language)
      return if existing_translation.present?

      # Perform translation
      result = TranslationService.new(
        post: post,
        target_language: target_language
      ).call

      if result.failure?
        Rails.logger.error("Translation failed for post #{post_id}: #{result.error}")
      end
    end
  end
end
