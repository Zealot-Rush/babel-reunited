# frozen_string_literal: true

require "rails_helper"

RSpec.describe DivineRapierAiTranslator::PostTranslation, type: :model do
  fab!(:post)

  describe "validations" do
    it "validates presence of language" do
      translation = described_class.new(post: post, translated_content: "test")
      expect(translation).not_to be_valid
      expect(translation.errors[:language]).to include("can't be blank")
    end

    it "validates presence of translated_content" do
      translation = described_class.new(post: post, language: "es")
      expect(translation).not_to be_valid
      expect(translation.errors[:translated_content]).to include("can't be blank")
    end

    it "validates uniqueness of post_id and language combination" do
      described_class.create!(post: post, language: "es", translated_content: "test")
      duplicate = described_class.new(post: post, language: "es", translated_content: "test2")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:post_id]).to include("has already been taken")
    end

    it "validates language format" do
      translation = described_class.new(post: post, language: "invalid", translated_content: "test")
      expect(translation).not_to be_valid
      expect(translation.errors[:language]).to include("must be a valid language code")
    end
  end

  describe "associations" do
    it "belongs to post" do
      translation = described_class.create!(post: post, language: "es", translated_content: "test")
      expect(translation.post).to eq(post)
    end
  end

  describe "scopes" do
    let!(:spanish_translation) { described_class.create!(post: post, language: "es", translated_content: "test") }
    let!(:french_translation) { described_class.create!(post: post, language: "fr", translated_content: "test") }

    it "filters by language" do
      expect(described_class.by_language("es")).to include(spanish_translation)
      expect(described_class.by_language("es")).not_to include(french_translation)
    end

    it "orders by created_at desc" do
      expect(described_class.recent.first).to eq(french_translation)
    end
  end

  describe "class methods" do
    let!(:translation) { described_class.create!(post: post, language: "es", translated_content: "test") }

    it "finds translation by post and language" do
      found = described_class.find_translation(post.id, "es")
      expect(found).to eq(translation)
    end

    it "returns nil when translation not found" do
      found = described_class.find_translation(post.id, "fr")
      expect(found).to be_nil
    end
  end

  describe "instance methods" do
    let(:translation) do
      described_class.create!(
        post: post,
        language: "es",
        translated_content: "test",
        source_language: "en",
        metadata: { confidence: 0.95 }
      )
    end

    it "detects if source language was detected" do
      expect(translation.source_language_detected?).to be true
    end

    it "returns provider info from metadata" do
      expect(translation.provider_info).to eq({})
    end

    it "returns translation confidence" do
      expect(translation.translation_confidence).to eq(0.95)
    end
  end
end
