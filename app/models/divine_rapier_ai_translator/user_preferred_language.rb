# frozen_string_literal: true

module BabelReunited
  class UserPreferredLanguage < ActiveRecord::Base
    self.table_name = "user_preferred_languages"

    belongs_to :user

    validates :language, length: { maximum: 10 }
    validates :enabled, inclusion: { in: [true, false] }
  end
end
