# frozen_string_literal: true

require "rails_helper"

RSpec.describe DivineRapierAiTranslator::TranslationService, type: :service do
  fab!(:post) { Fabricate(:post, raw: "Hello [world](https://example.com)!", cooked: "<p>Hello <a href=\"https://example.com\">world</a>!</p>") }

  describe "#call" do
    context "when using cooked content" do
      it "uses cooked HTML content for translation" do
        service = described_class.new(post: post, target_language: "es")
        
        # Mock the API call to avoid actual API requests
        allow(service).to receive(:call_openai_api).and_return({
          translated_text: "<p>Hola <a href=\"https://example.com\">mundo</a>!</p>",
          source_language: "en",
          confidence: 0.95,
          provider_info: { model: "gpt-3.5-turbo", tokens_used: 50, provider: "openai" }
        })
        
        result = service.call
        
        expect(result.success?).to be true
        expect(result[:translation]).to be_present
        expect(result[:translation].translated_content).to eq("<p>Hola <a href=\"https://example.com\">mundo</a>!</p>")
      end
    end

    context "when building translation prompt" do
      it "includes HTML-specific instructions" do
        service = described_class.new(post: post, target_language: "es")
        
        prompt = service.send(:build_translation_prompt, "<p>Hello <a href=\"https://example.com\">world</a>!</p>", "es")
        
        expect(prompt).to include("HTML content")
        expect(prompt).to include("Translate ONLY the text content, NOT the HTML tags")
        expect(prompt).to include("Preserve ALL HTML tags exactly as they are")
        expect(prompt).to include("Keep ALL href attributes and URLs unchanged")
      end
    end

    context "when content preparation" do
      it "uses cooked content instead of raw content" do
        service = described_class.new(post: post, target_language: "es")
        
        prepared_content = service.send(:prepare_content_for_translation, post.cooked)
        
        expect(prepared_content).to eq(post.cooked)
        expect(prepared_content).to include("<p>")
        expect(prepared_content).to include("<a href=")
        expect(prepared_content).not_to eq(post.raw)
      end
    end
  end
end
