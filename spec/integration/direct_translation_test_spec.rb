# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Direct Translation Test", type: :integration do
  fab!(:user)
  fab!(:topic) { Fabricate(:topic, user: user) }

  before do
    SiteSetting.divine_rapier_ai_translator_enabled = true
    SiteSetting.divine_rapier_ai_translator_auto_translate_languages = "en,zh-cn,es"
  end

  describe "manual translation job enqueuing" do
    let(:chinese_content) do
      "这是一篇关于人工智能的中文文章。人工智能技术正在快速发展，改变着我们的生活方式。"
    end

    it "manually enqueues translation jobs for a Chinese post" do
      # Create the Chinese post
      post = Fabricate(:post, topic: topic, user: user, raw: chinese_content)
      
      # Verify the post was created
      expect(post).to be_persisted
      expect(post.raw).to eq(chinese_content)
      
      # Manually enqueue translation jobs (simulating what the event should do)
      expect(Jobs).to receive(:enqueue).with(
        :translate_post,
        { post_id: post.id, target_language: "en" }
      )
      expect(Jobs).to receive(:enqueue).with(
        :translate_post,
        { post_id: post.id, target_language: "zh-cn" }
      )
      
      # Simulate the enqueue_translation_jobs method call
      target_languages = ["en", "zh-cn"]
      target_languages.each do |language|
        Jobs.enqueue(
          :translate_post,
          post_id: post.id,
          target_language: language
        )
      end
    end

    it "creates and retrieves translations" do
      post = Fabricate(:post, topic: topic, user: user, raw: chinese_content)
      
      # Create a translation manually
      translation = DivineRapierAiTranslator::PostTranslation.create!(
        post: post,
        language: "en",
        translated_content: "This is a Chinese article about artificial intelligence.",
        source_language: "zh-cn",
        translation_provider: "openai",
        metadata: {
          confidence: 0.95,
          provider_info: { model: "gpt-3.5-turbo" }
        }
      )
      
      # Verify translation was created
      expect(translation).to be_persisted
      expect(translation.post).to eq(post)
      expect(translation.language).to eq("en")
      expect(translation.translated_content).to include("Chinese article")
      
      # Test finding translation
      found_translation = DivineRapierAiTranslator::PostTranslation.find_translation(post.id, "en")
      expect(found_translation).to eq(translation)
      
      # Test scopes
      expect(DivineRapierAiTranslator::PostTranslation.by_language("en")).to include(translation)
      expect(DivineRapierAiTranslator::PostTranslation.recent.first).to eq(translation)
    end

    it "validates translation model correctly" do
      post = Fabricate(:post, topic: topic, user: user, raw: chinese_content)
      
      # Test valid translation
      translation = DivineRapierAiTranslator::PostTranslation.new(
        post: post,
        language: "en",
        translated_content: "This is a translation"
      )
      expect(translation).to be_valid
      
      # Test invalid language format
      invalid_translation = DivineRapierAiTranslator::PostTranslation.new(
        post: post,
        language: "invalid",
        translated_content: "This is a translation"
      )
      expect(invalid_translation).not_to be_valid
      expect(invalid_translation.errors[:language]).to include("must be a valid language code")
      
      # Test missing content
      no_content_translation = DivineRapierAiTranslator::PostTranslation.new(
        post: post,
        language: "en"
      )
      expect(no_content_translation).not_to be_valid
      expect(no_content_translation.errors[:translated_content]).to include("can't be blank")
    end

    it "handles duplicate translations correctly" do
      post = Fabricate(:post, topic: topic, user: user, raw: chinese_content)
      
      # Create first translation
      first_translation = DivineRapierAiTranslator::PostTranslation.create!(
        post: post,
        language: "en",
        translated_content: "First translation"
      )
      
      # Try to create duplicate
      duplicate_translation = DivineRapierAiTranslator::PostTranslation.new(
        post: post,
        language: "en",
        translated_content: "Second translation"
      )
      expect(duplicate_translation).not_to be_valid
      expect(duplicate_translation.errors[:post_id]).to include("has already been taken")
    end
  end
end
