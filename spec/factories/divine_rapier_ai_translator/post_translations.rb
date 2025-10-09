# frozen_string_literal: true

FactoryBot.define do
  factory :post_translation, class: "DivineRapierAiTranslator::PostTranslation" do
    association :post
    language { "es" }
    translated_content { "Contenido traducido" }
    source_language { "en" }
    translation_provider { "openai" }
    metadata { { confidence: 0.95, provider_info: { model: "gpt-4" } } }
  end
end
