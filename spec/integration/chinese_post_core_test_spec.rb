# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Chinese Post Core Functionality Test", type: :integration do
  fab!(:user)
  fab!(:topic) { Fabricate(:topic, user: user) }

  before do
    SiteSetting.divine_rapier_ai_translator_enabled = true
    SiteSetting.divine_rapier_ai_translator_auto_translate_languages = "en,zh,es"
  end

  describe "core translation functionality" do
    let(:chinese_content) do
      "这是一篇关于人工智能的中文文章。人工智能技术正在快速发展，改变着我们的生活方式。"
    end

    it "creates a Chinese post and verifies basic functionality" do
      # Create the Chinese post
      post = Fabricate(:post, topic: topic, user: user, raw: chinese_content)
      
      # Verify the post was created successfully
      expect(post).to be_persisted
      expect(post.raw).to eq(chinese_content)
      expect(post.user).to eq(user)
      expect(post.topic).to eq(topic)
      
      # Verify the post has no translations initially
      expect(DivineRapierAiTranslator::PostTranslation.where(post: post)).to be_empty
    end

    it "creates and manages translations correctly" do
      post = Fabricate(:post, topic: topic, user: user, raw: chinese_content)
      
      # Create English translation
      english_translation = DivineRapierAiTranslator::PostTranslation.create!(
        post: post,
        language: "en",
        translated_content: "This is a Chinese article about artificial intelligence. AI technology is developing rapidly and changing our way of life.",
        source_language: "zh",
        translation_provider: "openai",
        metadata: {
          confidence: 0.95,
          provider_info: { 
            model: "gpt-3.5-turbo",
            tokens_used: 120,
            provider: "openai"
          }
        }
      )
      
      # Verify translation was created
      expect(english_translation).to be_persisted
      expect(english_translation.post).to eq(post)
      expect(english_translation.language).to eq("en")
      expect(english_translation.translated_content).to include("artificial intelligence")
      expect(english_translation.source_language).to eq("zh")
      expect(english_translation.translation_provider).to eq("openai")
      expect(english_translation.translation_confidence).to eq(0.95)
      expect(english_translation.source_language_detected?).to be true
      
      # Test finding translation
      found_translation = DivineRapierAiTranslator::PostTranslation.find_translation(post.id, "en")
      expect(found_translation).to eq(english_translation)
      
      # Create Japanese translation
      japanese_translation = DivineRapierAiTranslator::PostTranslation.create!(
        post: post,
        language: "ja",
        translated_content: "これは人工知能に関する中国語の記事です。AI技術は急速に発展し、私たちの生活様式を変えています。",
        source_language: "zh",
        translation_provider: "openai",
        metadata: {
          confidence: 0.92,
          provider_info: { 
            model: "gpt-3.5-turbo",
            tokens_used: 110,
            provider: "openai"
          }
        }
      )
      
      # Verify both translations exist
      expect(DivineRapierAiTranslator::PostTranslation.where(post: post).count).to eq(2)
      expect(DivineRapierAiTranslator::PostTranslation.find_translation(post.id, "ja")).to eq(japanese_translation)
      
      # Test scopes
      expect(DivineRapierAiTranslator::PostTranslation.by_language("en")).to include(english_translation)
      expect(DivineRapierAiTranslator::PostTranslation.by_language("ja")).to include(japanese_translation)
      expect(DivineRapierAiTranslator::PostTranslation.by_language("en")).not_to include(japanese_translation)
      
      # Test recent scope (should be ordered by created_at desc)
      recent_translations = DivineRapierAiTranslator::PostTranslation.recent
      expect(recent_translations.first).to eq(japanese_translation) # Most recent
      expect(recent_translations.last).to eq(english_translation) # Oldest
    end

    it "validates translation model constraints" do
      post = Fabricate(:post, topic: topic, user: user, raw: chinese_content)
      
      # Test valid translation
      valid_translation = DivineRapierAiTranslator::PostTranslation.new(
        post: post,
        language: "en",
        translated_content: "This is a valid translation"
      )
      expect(valid_translation).to be_valid
      
      # Test invalid language format
      invalid_language = DivineRapierAiTranslator::PostTranslation.new(
        post: post,
        language: "invalid-language-code",
        translated_content: "This should be invalid"
      )
      expect(invalid_language).not_to be_valid
      expect(invalid_language.errors[:language]).to include("must be a valid language code")
      
      # Test missing content
      no_content = DivineRapierAiTranslator::PostTranslation.new(
        post: post,
        language: "en"
      )
      expect(no_content).not_to be_valid
      expect(no_content.errors[:translated_content]).to include("can't be blank")
      
      # Test missing language
      no_language = DivineRapierAiTranslator::PostTranslation.new(
        post: post,
        translated_content: "This has no language"
      )
      expect(no_language).not_to be_valid
      expect(no_language.errors[:language]).to include("can't be blank")
    end

    it "prevents duplicate translations for same post and language" do
      post = Fabricate(:post, topic: topic, user: user, raw: chinese_content)
      
      # Create first translation
      first_translation = DivineRapierAiTranslator::PostTranslation.create!(
        post: post,
        language: "en",
        translated_content: "First translation"
      )
      
      # Try to create duplicate (should fail)
      duplicate_translation = DivineRapierAiTranslator::PostTranslation.new(
        post: post,
        language: "en",
        translated_content: "Second translation"
      )
      
      expect(duplicate_translation).not_to be_valid
      expect(duplicate_translation.errors[:post_id]).to include("has already been taken")
      
      # But different language should work
      different_language = DivineRapierAiTranslator::PostTranslation.create!(
        post: post,
        language: "ja",
        translated_content: "Japanese translation"
      )
      
      expect(different_language).to be_persisted
      expect(DivineRapierAiTranslator::PostTranslation.where(post: post).count).to eq(2)
    end

    it "demonstrates translation job enqueuing simulation" do
      post = Fabricate(:post, topic: topic, user: user, raw: chinese_content)
      
      # Simulate what should happen when a Chinese post is created
      # This represents the core functionality we want to test
      target_languages = ["en", "zh-CN", "ja"]
      
      # For each target language, check if translation exists, if not, enqueue job
      target_languages.each do |language|
        existing_translation = DivineRapierAiTranslator::PostTranslation.find_translation(post.id, language)
        
        if existing_translation.nil?
          # This is where the job would be enqueued in the real system
          # For this test, we'll just verify the logic works
          expect(existing_translation).to be_nil
          
          # Simulate creating the translation (what the job would do)
          DivineRapierAiTranslator::PostTranslation.create!(
            post: post,
            language: language,
            translated_content: "Simulated translation for #{language}",
            source_language: "zh",
            translation_provider: "openai"
          )
        end
      end
      
      # Verify all translations were created
      expect(DivineRapierAiTranslator::PostTranslation.where(post: post).count).to eq(3)
      expect(DivineRapierAiTranslator::PostTranslation.find_translation(post.id, "en")).to be_present
      expect(DivineRapierAiTranslator::PostTranslation.find_translation(post.id, "zh-CN")).to be_present
      expect(DivineRapierAiTranslator::PostTranslation.find_translation(post.id, "ja")).to be_present
    end
  end
end
