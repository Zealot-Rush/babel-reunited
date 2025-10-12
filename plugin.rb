# frozen_string_literal: true

# name: divine-rapier-ai-translator
# about: AI-powered post translation plugin that automatically translates posts to multiple languages using third-party AI APIs
# meta_topic_id: TODO
# version: 0.1.0
# authors: Divine Rapier
# url: https://github.com/divine-rapier/discourse-ai-translator
# required_version: 2.7.0

enabled_site_setting :divine_rapier_ai_translator_enabled

module ::DivineRapierAiTranslator
  PLUGIN_NAME = "divine-rapier-ai-translator"
end

require_relative "lib/divine_rapier_ai_translator/engine"

# Load models BEFORE after_initialize
require_relative "app/models/divine_rapier_ai_translator/post_translation"
require_relative "app/models/divine_rapier_ai_translator/user_preferred_language"

after_initialize do
  # Load other required files
  require_relative "app/services/divine_rapier_ai_translator/translation_service"
  require_relative "app/jobs/regular/divine_rapier_ai_translator/translate_post_job"
  require_relative "app/jobs/regular/divine_rapier_ai_translator/batch_translate_posts_job"
  require_relative "app/controllers/divine_rapier_ai_translator/translations_controller"
  require_relative "app/controllers/divine_rapier_ai_translator/admin_controller"
  require_relative "app/serializers/divine_rapier_ai_translator/post_translation_serializer"
  require_relative "lib/divine_rapier_ai_translator/rate_limiter"
  require_relative "lib/divine_rapier_ai_translator/translation_logger"

  # Mount the engine routes
  Discourse::Application.routes.append do
    mount ::DivineRapierAiTranslator::Engine, at: "/ai-translator"
  end

  # Extend Post model with translation functionality
  reloadable_patch do
    Post.class_eval do
      has_many :post_translations, 
               class_name: "DivineRapierAiTranslator::PostTranslation",
               dependent: :destroy

      def translate_to_language(target_language)
        DivineRapierAiTranslator::TranslationService.new(
          post: self,
          target_language: target_language
        ).call
      end

      def get_translation(language)
        post_translations.find_by(language: language)
      end

      def has_translation?(language)
        post_translations.exists?(language: language)
      end

      def available_translations
        post_translations.pluck(:language)
      end

      def enqueue_translation_jobs(target_languages)
        return if target_languages.blank?

        target_languages.each do |language|
          next if has_translation?(language)

          Jobs.enqueue(
            DivineRapierAiTranslatorTranslatePostJob,
            post_id: id,
            target_language: language
          )
        end
      end

      def enqueue_batch_translation(target_languages)
        return if target_languages.blank?

        Jobs.enqueue(
          DivineRapierAiTranslatorBatchTranslatePostsJob,
          post_ids: [id],
          target_languages: target_languages
        )
      end
    end
  end

  reloadable_patch do
    User.class_eval do
      has_one :user_preferred_language, class_name: "DivineRapierAiTranslator::UserPreferredLanguage", dependent: :destroy
    end

    def enabled_language_translator
      self.user_preferred_language&.enabled
    end

    def preferred_language
      self.user_preferred_language&.language
    end
  end

  # Add translation methods to PostSerializer
  add_to_serializer(:post, :available_translations, include_condition: -> { true }) do
    object.available_translations
  end

  add_to_serializer(:post, :post_translations, include_condition: -> { true }) do
    object.post_translations.recent.limit(5).map do |translation|
      DivineRapierAiTranslator::PostTranslationSerializer.new(translation).as_json
    end
  end

  add_to_serializer(:post, :show_translation_widget, include_condition: -> { true }) do
    object.post_translations.exists?
  end

  add_to_serializer(:post, :show_translation_button, include_condition: -> { true }) do
    true
  end

  add_to_serializer(:user, :user_preferred_language, include_condition: -> { true }) do
    object.user_preferred_language&.language
  end

  # Event handlers for automatic translation
  on(:post_created) do |post|
    next unless SiteSetting.divine_rapier_ai_translator_enabled
    next if post.raw.blank?

    auto_translate_languages = SiteSetting.divine_rapier_ai_translator_auto_translate_languages
    if auto_translate_languages.present?
      languages = auto_translate_languages.split(",").map(&:strip)
      post.enqueue_translation_jobs(languages)
    end
  end

  on(:post_edited) do |post|
    next unless SiteSetting.divine_rapier_ai_translator_enabled
    next if post.raw.blank?

    # Re-translate existing translations when post is edited
    existing_languages = post.available_translations
    if existing_languages.any?
      post.enqueue_translation_jobs(existing_languages)
    end
  end

  on(:post_destroyed) do |post|
    # Translations will be automatically deleted due to dependent: :destroy
  end

  # User login event handler for language preference prompt
  on(:user_logged_in) do |user|
    next unless SiteSetting.divine_rapier_ai_translator_enabled
    next if user.user_preferred_language.present?
    
    # Use MessageBus to trigger frontend modal display
    MessageBus.publish("/language-preference-prompt/#{user.id}", {
      user_id: user.id,
      username: user.username
    })
  end

  # Add admin route
  add_admin_route "ai_translator.title", "ai-translator"

  # Register frontend widgets and components
  register_asset "stylesheets/translation-widgets.scss"
end
