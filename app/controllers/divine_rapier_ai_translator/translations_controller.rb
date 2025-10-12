# frozen_string_literal: true

module DivineRapierAiTranslator
  class TranslationsController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    before_action :ensure_logged_in
    before_action :find_post, except: [:set_user_preferred_language, :get_user_preferred_language]

    def index
      translations = @post.post_translations.recent
      render_serialized(translations, PostTranslationSerializer)
    end

    def show
      translation = @post.get_translation(params[:language])
      return render json: { error: "Translation not found" }, status: :not_found unless translation

      render_serialized(translation, PostTranslationSerializer)
    end

    def create
      target_language = params[:target_language]

      return render json: { error: "Target language required" }, status: :bad_request if target_language.blank?

      # Check if translation already exists
      if @post.has_translation?(target_language)
        translation = @post.get_translation(target_language)
        return render_serialized(translation, PostTranslationSerializer)
      end

      # Enqueue translation job
      @post.enqueue_translation_jobs([target_language])

      render json: { message: "Translation job enqueued" }
    end

    def destroy
      translation = @post.post_translations.find_by(language: params[:language])
      return render json: { error: "Translation not found" }, status: :not_found unless translation

      translation.destroy!
      render json: { message: "Translation deleted" }
    end

    def get_user_preferred_language
      preferred_language = current_user.user_preferred_language
      
      if preferred_language
        render json: { language: preferred_language.language }
      else
        render json: { language: nil }
      end
    end

    def set_user_preferred_language
      language = params[:language]
      
      if language.blank?
        return render json: { error: "Language is required" }, status: :bad_request
      end
      
      # Validate language code format
      unless language.match?(/\A[a-z]{2}\z/)
        return render json: { error: "Invalid language code format" }, status: :bad_request
      end
      
      preferred_language = current_user.user_preferred_language || 
                          current_user.build_user_preferred_language
      
      preferred_language.language = language
      
      if preferred_language.save
        render json: { success: true, language: language }
      else
        render json: { errors: preferred_language.errors.full_messages }, status: :bad_request
      end
    end

    private

    def find_post
      @post = Post.find_by(id: params[:post_id])
      return render json: { error: "Post not found" }, status: :not_found unless @post

      # Check permissions
      render json: { error: "Access denied" }, status: :forbidden unless guardian.can_see?(@post)
    end
  end
end
