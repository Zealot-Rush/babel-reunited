# frozen_string_literal: true

module DivineRapierAiTranslator
  class PostTranslationSerializer < ApplicationSerializer
    attributes :id, :language, :translated_content, :source_language, 
               :translation_provider, :created_at, :updated_at, :confidence

    def confidence
      object.translation_confidence
    end

    def source_language_detected?
      object.source_language_detected?
    end
  end
end
