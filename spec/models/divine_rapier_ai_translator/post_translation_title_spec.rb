# frozen_string_literal: true

require "rails_helper"

RSpec.describe DivineRapierAiTranslator::PostTranslation, type: :model do
  let(:user) { Fabricate(:user) }
  let(:topic) { Fabricate(:topic, title: "Test Topic Title", user: user) }
  let(:post) { Fabricate(:post, topic: topic, user: user, post_number: 1) }
  let(:reply_post) { Fabricate(:post, topic: topic, user: user, post_number: 2) }
  let(:language) { "zh-cn" }

  describe "translated_title validations" do
    it "allows blank translated_title" do
      translation = described_class.new(
        post: post,
        language: language,
        translated_content: "translated content",
        translated_title: ""
      )
      expect(translation).to be_valid
    end

    it "validates translated_title length" do
      long_title = "a" * 256
      translation = described_class.new(
        post: post,
        language: language,
        translated_content: "translated content",
        translated_title: long_title
      )
      expect(translation).not_to be_valid
      expect(translation.errors[:translated_title]).to include("is too long (maximum is 255 characters)")
    end
  end

  describe "#has_translated_title?" do
    it "returns true when translated_title is present" do
      translation = Fabricate(:post_translation, post: post, language: language, translated_title: "translated title")
      expect(translation.has_translated_title?).to be true
    end

    it "returns false when translated_title is blank" do
      translation = Fabricate(:post_translation, post: post, language: language, translated_title: "")
      expect(translation.has_translated_title?).to be false
    end
  end

  describe "#translated_title_or_original" do
    it "returns translated_title when present" do
      translation = Fabricate(:post_translation, post: post, language: language, translated_title: "translated title")
      expect(translation.translated_title_or_original).to eq("translated title")
    end

    it "returns original topic title when translated_title is blank" do
      translation = Fabricate(:post_translation, post: post, language: language, translated_title: "")
      expect(translation.translated_title_or_original).to eq("Test Topic Title")
    end
  end

  describe ".find_topic_translation" do
    it "returns translated title for topic" do
      translation = Fabricate(:post_translation, post: post, language: language, translated_title: "translated title")
      result = described_class.find_topic_translation(topic.id, language)
      expect(result).to eq("translated title")
    end

    it "returns nil when no translation exists" do
      result = described_class.find_topic_translation(topic.id, language)
      expect(result).to be_nil
    end

    it "returns nil when first post doesn't exist" do
      post.destroy!
      result = described_class.find_topic_translation(topic.id, language)
      expect(result).to be_nil
    end
  end

  describe ".find_topic_translation_info" do
    it "returns translation object for topic" do
      translation = Fabricate(:post_translation, post: post, language: language, translated_title: "translated title")
      result = described_class.find_topic_translation_info(topic.id, language)
      expect(result).to eq(translation)
    end

    it "returns nil when no translation exists" do
      result = described_class.find_topic_translation_info(topic.id, language)
      expect(result).to be_nil
    end
  end
end
