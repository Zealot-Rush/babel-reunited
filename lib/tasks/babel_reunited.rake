# frozen_string_literal: true

# Rake tasks for Babel Reunited plugin
# These tasks are automatically loaded by Discourse when the plugin is activated
# See: lib/plugin/instance.rb line 839

namespace :babel_reunited do
  desc "Process posts without any translations and add translation jobs to Sidekiq"
  task process_missing_posts: :environment do |_, args|
    dry_run = ENV["DRY_RUN"] != "false"
    
    unless SiteSetting.babel_reunited_enabled
      puts "ERROR: Babel Reunited plugin is not enabled"
      puts "Please enable it in Site Settings first"
      exit 1
    end
    
    auto_translate_languages = SiteSetting.babel_reunited_auto_translate_languages
    if auto_translate_languages.blank?
      puts "ERROR: No auto-translate languages configured"
      puts "Please set babel_reunited_auto_translate_languages in Site Settings"
      exit 1
    end
    
    languages = auto_translate_languages.split(",").map(&:strip)
    puts "Auto-translate languages: #{languages.join(", ")}"
    puts ""
    
    # Find all posts that have no translations at all
    # Using subquery to find posts without any translation records
    posts_with_translations = BabelReunited::PostTranslation.select(:post_id).distinct
    posts_without_translations = Post
      .where.not(id: posts_with_translations)
      .where("raw IS NOT NULL AND raw != ''")
      .where(deleted_at: nil)
    
    total_count = posts_without_translations.count
    puts "Found #{total_count} posts without any translations"
    
    if total_count == 0
      puts "No posts need translation processing"
      next
    end
    
    if dry_run
      puts ""
      puts "DRY RUN mode - no jobs will be queued"
      puts "Use DRY_RUN=false to actually queue translation jobs"
      puts ""
      puts "Sample posts that would be processed:"
      posts_without_translations.limit(10).find_each do |post|
        puts "  Post ID: #{post.id}, Topic ID: #{post.topic_id}, User: #{post.user&.username || 'system'}"
      end
      if total_count > 10
        puts "  ... and #{total_count - 10} more posts"
      end
      puts ""
      puts "Would queue #{total_count * languages.size} translation jobs (#{total_count} posts × #{languages.size} languages)"
    else
      processed = 0
      failed = 0
      
      puts "Processing posts and queueing translation jobs..."
      posts_without_translations.find_each do |post|
        begin
          # Pre-create translation records to show "translating" status immediately
          languages.each do |language|
            post.create_or_update_translation_record(language)
          end
          
          # Enqueue translation jobs
          post.enqueue_translation_jobs(languages)
          processed += 1
          
          if processed % 100 == 0
            puts "Processed #{processed}/#{total_count} posts..."
          end
        rescue => e
          puts "Error processing post #{post.id}: #{e.message}"
          failed += 1
        end
      end
      
      puts ""
      puts "=" * 50
      puts "Processing complete"
      puts "=" * 50
      puts "Processed: #{processed} posts"
      puts "Failed: #{failed} posts"
      puts "Queued: #{processed * languages.size} translation jobs"
      puts "=" * 50
    end
  end
end

