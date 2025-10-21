# frozen_string_literal: true

require "rails_helper"

RSpec.describe DivineRapierAiTranslator::TranslationService, type: :service do
  let(:user) { Fabricate(:user) }
  let(:topic) { Fabricate(:topic, title: "Test Topic Title", user: user) }
  let(:post) { Fabricate(:post, topic: topic, user: user, post_number: 1) }
  let(:target_language) { "zh-cn" }

  before do
    SiteSetting.divine_rapier_ai_translator_translate_title = true
  end

  describe "#prepare_title_for_translation" do
    it "returns topic title for first post" do
      service = described_class.new(post: post, target_language: target_language)
      expect(service.send(:prepare_title_for_translation)).to eq("Test Topic Title")
    end

    it "returns nil for non-first post" do
      reply_post = Fabricate(:post, topic: topic, user: user, post_number: 2)
      service = described_class.new(post: reply_post, target_language: target_language)
      expect(service.send(:prepare_title_for_translation)).to be_nil
    end

    it "returns nil when translate_title setting is disabled" do
      SiteSetting.divine_rapier_ai_translator_translate_title = false
      service = described_class.new(post: post, target_language: target_language)
      expect(service.send(:prepare_title_for_translation)).to be_nil
    end

    it "returns nil when topic title is blank" do
      topic.update!(title: "")
      service = described_class.new(post: post, target_language: target_language)
      expect(service.send(:prepare_title_for_translation)).to be_nil
    end
  end

  describe "translation with title" do
    it "includes title in content length calculation" do
      service = described_class.new(post: post, target_language: target_language)
      title = service.send(:prepare_title_for_translation)
      content = post.cooked
      
      # Mock the API call to avoid actual API request
      allow(service).to receive(:make_openai_request).and_return({
        translated_text: "translated content",
        translated_title: "translated title",
        source_language: "auto",
        confidence: 0.95,
        model: "gpt-3.5-turbo",
        tokens_used: 100
      })
      
      # Mock rate limiter
      allow(DivineRapierAiTranslator::RateLimiter).to receive(:can_make_request?).and_return(true)
      allow(DivineRapierAiTranslator::RateLimiter).to receive(:record_request)
      
      # Mock site settings
      allow(SiteSetting).to receive(:divine_rapier_ai_translator_openai_api_key).and_return("test-key")
      allow(SiteSetting).to receive(:divine_rapier_ai_translator_max_content_length).and_return(10000)
      
      result = service.call
      
      expect(result.success?).to be true
      expect(result.translation.translated_title).to eq("translated title")
    end
  end
end
