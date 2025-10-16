# frozen_string_literal: true

class AddTranslatedTitleToPostTranslations < ActiveRecord::Migration[7.0]
  def change
    add_column :post_translations, :translated_title, :text
    add_index :post_translations, :translated_title, length: 255
  end
end
