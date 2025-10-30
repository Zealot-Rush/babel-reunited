# frozen_string_literal: true

module BabelReunited
  class PostTranslationSerializer < ApplicationSerializer
    attributes :id, :language, :translated_content, :translated_title, :source_language, 
               :translation_provider, :created_at, :updated_at, :confidence, :status

    def confidence
      object.translation_confidence
    end

    def source_language_detected?
      object.source_language_detected?
    end

    def has_translated_title?
      object.has_translated_title?
    end
  end
end
