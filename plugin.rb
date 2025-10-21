# frozen_string_literal: true

# name: divine-rapier-ai-translator
# about: AI-powered post translation plugin that automatically translates posts to multiple languages using third-party AI APIs
# meta_topic_id: TODO
# version: 0.1.0
# authors: Divine Rapier
# url: https://github.com/divine-rapier/discourse-ai-translator
# required_version: 2.7.0

enabled_site_setting :divine_rapier_ai_translator_enabled

register_asset "stylesheets/translated-title.scss"

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
          target_language: target_language,
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

      def enqueue_translation_jobs(target_languages, force_update: false)
        return if target_languages.blank?

        target_languages.each do |language|
          # Always enqueue translation job - no skipping based on existing translations
          Jobs.enqueue(
            Jobs::DivineRapierAiTranslator::TranslatePostJob,
            post_id: id,
            target_language: language,
            force_update: force_update,
          )
        end
      end

      def enqueue_batch_translation(target_languages)
        return if target_languages.blank?

        Jobs.enqueue(
          Jobs::DivineRapierAiTranslator::BatchTranslatePostsJob,
          post_ids: [id],
          target_languages: target_languages,
        )
      end
    end
  end

  reloadable_patch do
    User.class_eval do
      has_one :user_preferred_language,
              class_name: "DivineRapierAiTranslator::UserPreferredLanguage",
              dependent: :destroy
    end
  end

  # Add translation methods to PostSerializer
  add_to_serializer(:post, :available_translations, include_condition: -> { true }) do
    object.available_translations
  end

  add_to_serializer(:post, :post_translations, include_condition: -> { true }) do
    object
      .post_translations
      .recent
      .limit(5)
      .map do |translation|
        DivineRapierAiTranslator::PostTranslationSerializer.new(translation).as_json
      end
  end

  add_to_serializer(:post, :show_translation_widget, include_condition: -> { true }) do
    object.post_translations.exists?
  end

  add_to_serializer(:post, :show_translation_button, include_condition: -> { true }) { true }

  add_to_serializer(:current_user, :preferred_language, include_condition: -> { true }) do
    object.user_preferred_language&.language
  end

  add_to_serializer(:current_user, :preferred_language_enabled, include_condition: -> { true }) do
    object.user_preferred_language&.enabled
  end

  # Add translated title to Topic serializers
  add_to_serializer(:topic_view, :translated_title, include_condition: -> { 
    SiteSetting.divine_rapier_ai_translator_enabled && 
    scope&.user&.user_preferred_language&.enabled != false &&
    scope&.user&.user_preferred_language&.language.present?
  }) do
    user_preferred_language = scope.user.user_preferred_language
    return nil unless user_preferred_language&.enabled && user_preferred_language.language.present?
    
    # Get the first post's translation for the topic title
    first_post = object.topic.first_post
    return nil unless first_post
    
    translation = DivineRapierAiTranslator::PostTranslation.find_translation(
      first_post.id, 
      user_preferred_language.language
    )
    
    # Only return translated title if it exists and is completed
    if translation&.completed? && translation.translated_title.present?
      translation.translated_title
    else
      nil
    end
  end

  # Also add to listable topics for topic lists
  add_to_serializer(:listable_topic, :translated_title, include_condition: -> { 
    SiteSetting.divine_rapier_ai_translator_enabled && 
    scope&.user&.user_preferred_language&.enabled != false &&
    scope&.user&.user_preferred_language&.language.present?
  }) do
    user_preferred_language = scope.user.user_preferred_language
    return nil unless user_preferred_language&.enabled && user_preferred_language.language.present?
    
    first_post = object.first_post
    return nil unless first_post
    
    translation = DivineRapierAiTranslator::PostTranslation.find_translation(
      first_post.id, 
      user_preferred_language.language
    )
    
    # Only return translated title if it exists and is completed
    if translation&.completed? && translation.translated_title.present?
      translation.translated_title
    else
      nil
    end
  end

  # Add to topic list item serializer for topic lists
  add_to_serializer(:topic_list_item, :translated_title, include_condition: -> { 
    SiteSetting.divine_rapier_ai_translator_enabled && 
    scope&.user&.user_preferred_language&.enabled != false &&
    scope&.user&.user_preferred_language&.language.present?
  }) do
    user_preferred_language = scope.user.user_preferred_language
    return nil unless user_preferred_language&.enabled && user_preferred_language.language.present?
    
    first_post = object.first_post
    return nil unless first_post
    
    translation = DivineRapierAiTranslator::PostTranslation.find_translation(
      first_post.id, 
      user_preferred_language.language
    )
    
    # Only return translated title if it exists and is completed
    if translation&.completed? && translation.translated_title.present?
      translation.translated_title
    else
      nil
    end
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
    post.enqueue_translation_jobs(existing_languages, force_update: true) if existing_languages.any?
  end

  on(:post_destroyed) do |post|
    # Translations will be automatically deleted due to dependent: :destroy
  end

  # User login event handler for language preference prompt
  on(:user_logged_in) do |user|
    next unless SiteSetting.divine_rapier_ai_translator_enabled
    next if user.user_preferred_language.present?

    # Use MessageBus to trigger frontend modal display
    MessageBus.publish(
      "/language-preference-prompt/#{user.id}",
      { user_id: user.id, username: user.username },
    )
  end

  # Add admin route
  add_admin_route "admin.site_settings.categories.divine_rapier_ai_translator", "ai-translator", use_new_show_route: true

  # Register frontend widgets and components
  register_asset "stylesheets/translation-widgets.scss"
  register_asset "stylesheets/preferences.scss"
  register_asset "stylesheets/language-tabs.scss"
  register_asset "stylesheets/language-preference-modal.scss"
end
