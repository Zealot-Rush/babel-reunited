# frozen_string_literal: true

module DivineRapierAiTranslator
  class PostTranslation < ActiveRecord::Base
    self.table_name = "post_translations"

    belongs_to :post

    validates :language, presence: true, length: { maximum: 10 }
    validates :translated_content, presence: true
    validates :post_id, uniqueness: { scope: :language }
    validates :language, format: { with: /\A[a-z]{2}(-[A-Z]{2})?\z/, message: "must be a valid language code" }

    scope :by_language, ->(lang) { where(language: lang) }
    scope :recent, -> { order(created_at: :desc) }

    def self.find_translation(post_id, language)
      find_by(post_id: post_id, language: language)
    end

    def self.translate_post(post, target_language)
      find_translation(post.id, target_language)
    end

    def source_language_detected?
      source_language.present?
    end

    def provider_info
      metadata["provider_info"] || {}
    end

    def translation_confidence
      metadata["confidence"] || 0.0
    end
  end
end
