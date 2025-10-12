# frozen_string_literal: true

class AddEnabledColumnToUserPreferredLanguages < ActiveRecord::Migration[7.0]
  def change
    # Add enabled column with default value true (if it doesn't exist)
    unless column_exists?(:user_preferred_languages, :enabled)
      add_column :user_preferred_languages, :enabled, :boolean, null: false, default: true
    end
    
    # Modify language column to allow null and set default value to 'en'
    change_column :user_preferred_languages, :language, :string, null: true, limit: 10, default: 'en'
  end
end
