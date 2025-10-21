# frozen_string_literal: true

require "rails_helper"

RSpec.describe DivineRapierAiTranslator::TranslatePostJob, type: :job do
  fab!(:post) { Fabricate(:post, raw: "Hello world") }
  fab!(:user)

  before do
    SiteSetting.divine_rapier_ai_translator_enabled = true
  end

  describe "#execute" do
    let(:job) { described_class.new }
    let(:translation_service) { instance_double(DivineRapierAiTranslator::TranslationService) }
    let(:success_context) { instance_double(Service::Base::Context, success?: true, failure?: false) }
    let(:failure_context) do
      context = double("Context", success?: false, failure?: true, error: "API Error")
      context
    end

    before do
      allow(DivineRapierAiTranslator::TranslationService).to receive(:new).and_return(translation_service)
      allow(translation_service).to receive(:call).and_return(success_context)
    end

    it "translates post to target language" do
      expect(DivineRapierAiTranslator::TranslationService).to receive(:new).with(
        post: post,
        target_language: "zh-cn"
      ).and_return(translation_service)
      
      expect(translation_service).to receive(:call).and_return(success_context)

      job.execute(post_id: post.id, target_language: "zh-cn")
    end

    it "skips if post_id is blank" do
      expect(DivineRapierAiTranslator::TranslationService).not_to receive(:new)
      
      job.execute(post_id: nil, target_language: "zh-cn")
    end

    it "skips if target_language is blank" do
      expect(DivineRapierAiTranslator::TranslationService).not_to receive(:new)
      
      job.execute(post_id: post.id, target_language: nil)
    end

    it "skips if post is not found" do
      expect(DivineRapierAiTranslator::TranslationService).not_to receive(:new)
      
      job.execute(post_id: 99999, target_language: "zh-cn")
    end

    it "skips if post is deleted" do
      post.update!(deleted_at: Time.current)
      
      expect(DivineRapierAiTranslator::TranslationService).not_to receive(:new)
      
      job.execute(post_id: post.id, target_language: "zh-cn")
    end

    it "skips if post is hidden" do
      post.update!(hidden: true)
      
      expect(DivineRapierAiTranslator::TranslationService).not_to receive(:new)
      
      job.execute(post_id: post.id, target_language: "zh-cn")
    end

    it "skips if translation already exists" do
      DivineRapierAiTranslator::PostTranslation.create!(
        post: post,
        language: "zh-cn",
        translated_content: "你好世界"
      )
      
      expect(DivineRapierAiTranslator::TranslationService).not_to receive(:new)
      
      job.execute(post_id: post.id, target_language: "zh-cn")
    end

    it "logs error when translation fails" do
      allow(translation_service).to receive(:call).and_return(failure_context)
      
      expect(Rails.logger).to receive(:error).with("Translation failed for post #{post.id}: API Error")
      
      job.execute(post_id: post.id, target_language: "zh-cn")
    end
  end
end
