# frozen_string_literal: true

module DivineRapierAiTranslator
  class UserPreferredLanguage < ActiveRecord::Base
    self.table_name = "user_preferred_languages"

    belongs_to :user

    validates :language, presence: true, length: { maximum: 10 }
  end
end
