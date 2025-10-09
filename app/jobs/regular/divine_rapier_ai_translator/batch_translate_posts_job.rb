# frozen_string_literal: true

module DivineRapierAiTranslator
  class BatchTranslatePostsJob < ::Jobs::Base
    def execute(args)
      post_ids = args[:post_ids]
      target_languages = args[:target_languages] || []

      return if post_ids.blank? || target_languages.blank?

      post_ids.each do |post_id|
        target_languages.each do |language|
          # Enqueue individual translation jobs with delay to avoid rate limiting
          delay = rand(1..5).seconds
          Jobs.enqueue_in(
            delay,
            :translate_post,
            post_id: post_id,
            target_language: language
          )
        end
      end
    end
  end
end
