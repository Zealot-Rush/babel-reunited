# frozen_string_literal: true

class CreateUserPreferredLanguages < ActiveRecord::Migration[7.0]
  def change
    create_table :user_preferred_languages do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.string :language, null: false, limit: 10
      t.timestamps
    end

    add_index :user_preferred_languages, [:user_id, :language], unique: true
    add_index :user_preferred_languages, :language
  end
end
