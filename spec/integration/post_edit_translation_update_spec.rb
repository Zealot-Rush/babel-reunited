# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Post Edit Translation Update", type: :model do
  fab!(:post) { Fabricate(:post, raw: "Hello world!", cooked: "<p>Hello world!</p>") }

  describe "TranslationService with force_update" do
    it "updates existing translation when force_update is true" do
      # Create initial translation
      translation = DivineRapierAiTranslator::PostTranslation.create!(
        post: post,
        language: "es",
        translated_content: "<p>Hola mundo!</p>",
        source_language: "en",
        translation_provider: "openai"
      )

      # Mock API response
      allow_any_instance_of(DivineRapierAiTranslator::TranslationService).to receive(:call_openai_api).and_return({
        translated_text: "<p>Hola mundo actualizado!</p>",
        source_language: "en",
        confidence: 0.95,
        provider_info: { model: "gpt-3.5-turbo", tokens_used: 50, provider: "openai" }
      })

      # Call service with force_update
      service = DivineRapierAiTranslator::TranslationService.new(
        post: post,
        target_language: "es",
        force_update: true
      )

      result = service.call

      expect(result.success?).to be true
      expect(result[:translation]).to eq(translation)
      expect(result[:translation].translated_content).to eq("<p>Hola mundo actualizado!</p>")
    end

    it "returns existing translation when force_update is false" do
      # Create initial translation
      translation = DivineRapierAiTranslator::PostTranslation.create!(
        post: post,
        language: "es",
        translated_content: "<p>Hola mundo!</p>",
        source_language: "en",
        translation_provider: "openai"
      )

      # Call service without force_update
      service = DivineRapierAiTranslator::TranslationService.new(
        post: post,
        target_language: "es",
        force_update: false
      )

      result = service.call

      expect(result.success?).to be true
      expect(result[:translation]).to eq(translation)
      expect(result[:translation].translated_content).to eq("<p>Hola mundo!</p>")
    end
  end
end
