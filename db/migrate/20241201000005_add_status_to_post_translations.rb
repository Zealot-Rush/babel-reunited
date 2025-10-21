# frozen_string_literal: true

class AddStatusToPostTranslations < ActiveRecord::Migration[7.0]
  def change
    add_column :post_translations, :status, :string, default: 'completed', null: false
    add_index :post_translations, :status
    
    # 更新现有记录的状态为 completed
    reversible do |dir|
      dir.up do
        execute "UPDATE post_translations SET status = 'completed' WHERE status IS NULL"
      end
    end
  end
end
