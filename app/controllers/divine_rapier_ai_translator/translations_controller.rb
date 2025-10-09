# frozen_string_literal: true

module DivineRapierAiTranslator
  class TranslationsController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    before_action :ensure_logged_in
    before_action :find_post

    def index
      translations = @post.post_translations.recent
      render_serialized(translations, PostTranslationSerializer)
    end

    def show
      translation = @post.get_translation(params[:language])
      return render json: { error: "Translation not found" }, status: 404 unless translation

      render_serialized(translation, PostTranslationSerializer)
    end

    def create
      target_language = params[:target_language]

      return render json: { error: "Target language required" }, status: 400 if target_language.blank?

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
      return render json: { error: "Translation not found" }, status: 404 unless translation

      translation.destroy!
      render json: { message: "Translation deleted" }
    end

    private

    def find_post
      @post = Post.find_by(id: params[:post_id])
      return render json: { error: "Post not found" }, status: 404 unless @post

      # Check permissions
      render json: { error: "Access denied" }, status: 403 unless guardian.can_see?(@post)
    end
  end
end
