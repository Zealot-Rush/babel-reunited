# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Post Edit Event Trigger", type: :model do
  fab!(:post) { Fabricate(:post, raw: "Hello world!", cooked: "<p>Hello world!</p>") }

  describe "post_edited event" do
    it "triggers translation update when post is edited" do
      # Create initial translation
      translation = DivineRapierAiTranslator::PostTranslation.create!(
        post: post,
        language: "es",
        translated_content: "<p>Hola mundo!</p>",
        source_language: "en",
        translation_provider: "openai"
      )

      # Mock the enqueue method to verify it's called
      allow(post).to receive(:enqueue_translation_jobs).and_call_original

      # Edit the post
      post.update!(raw: "Hello updated world!", cooked: "<p>Hello updated world!</p>")

      # Manually trigger the event to test
      DiscourseEvent.trigger(:post_edited, post)

      # Verify that enqueue_translation_jobs was called with force_update: true
      expect(post).to have_received(:enqueue_translation_jobs).with(["es"], force_update: true)
    end

    it "does not trigger translation update when no existing translations" do
      # Mock the enqueue method to verify it's not called
      allow(post).to receive(:enqueue_translation_jobs).and_call_original

      # Edit the post
      post.update!(raw: "Hello updated world!", cooked: "<p>Hello updated world!</p>")

      # Manually trigger the event to test
      DiscourseEvent.trigger(:post_edited, post)

      # Verify that enqueue_translation_jobs was not called
      expect(post).not_to have_received(:enqueue_translation_jobs)
    end

    it "checks site setting conditions" do
      # Disable the plugin
      SiteSetting.divine_rapier_ai_translator_enabled = false

      # Create initial translation
      DivineRapierAiTranslator::PostTranslation.create!(
        post: post,
        language: "es",
        translated_content: "<p>Hola mundo!</p>",
        source_language: "en",
        translation_provider: "openai"
      )

      # Mock the enqueue method to verify it's not called
      allow(post).to receive(:enqueue_translation_jobs).and_call_original

      # Edit the post
      post.update!(raw: "Hello updated world!", cooked: "<p>Hello updated world!</p>")

      # Manually trigger the event to test
      DiscourseEvent.trigger(:post_edited, post)

      # Verify that enqueue_translation_jobs was not called
      expect(post).not_to have_received(:enqueue_translation_jobs)

      # Re-enable the plugin
      SiteSetting.divine_rapier_ai_translator_enabled = true
    end
  end
end
