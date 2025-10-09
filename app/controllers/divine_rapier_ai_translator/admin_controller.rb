# frozen_string_literal: true

module DivineRapierAiTranslator
  class AdminController < ::Admin::AdminController
    requires_plugin PLUGIN_NAME

    def index
      # Statistics will be calculated in the view
    end

    def stats
      render json: {
        total_translations: PostTranslation.count,
        unique_languages: PostTranslation.distinct.count(:language),
        language_distribution: PostTranslation.group(:language).count,
        recent_translations: PostTranslation.includes(:post).recent.limit(10).map do |t|
          {
            id: t.id,
            post_id: t.post_id,
            language: t.language,
            provider: t.translation_provider,
            created_at: t.created_at
          }
        end
      }
    end
  end
end
