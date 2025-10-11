# frozen_string_literal: true

module DivineRapierAiTranslator
  module PostExtension
    extend ActiveSupport::Concern

    included do
      has_many :post_translations, 
               class_name: "DivineRapierAiTranslator::PostTranslation",
               dependent: :destroy
    end

    def translate_to_language(target_language)
      DivineRapierAiTranslator::TranslationService.new(
        post: self,
        target_language: target_language
      ).call
    end

    def get_translation(language)
      post_translations.find_by(language: language)
    end

    def has_translation?(language)
      post_translations.exists?(language: language)
    end

    def available_translations
      post_translations.pluck(:language)
    end

    def enqueue_translation_jobs(target_languages)
      return if target_languages.blank?

      target_languages.each do |language|
        next if has_translation?(language)

        Jobs.enqueue(
          :translate_post,
          post_id: id,
          target_language: language
        )
      end
    end

    def enqueue_batch_translation(target_languages)
      return if target_languages.blank?

      Jobs.enqueue(
        :batch_translate_posts,
        post_ids: [id],
        target_languages: target_languages
      )
    end
  end
end