# frozen_string_literal: true

module DivineRapierAiTranslator
  class TranslationLogger
    LOG_FILE_PATH = Rails.root.join("log", "ai_translation.log")
    
    def self.log_translation_start(post_id:, target_language:, content_length:, force_update: false)
      log_entry = {
        timestamp: Time.current.iso8601,
        event: "translation_started",
        post_id: post_id,
        target_language: target_language,
        content_length: content_length,
        force_update: force_update,
        status: "started"
      }
      
      write_log(log_entry)
    end
    
    def self.log_translation_success(post_id:, target_language:, translation_id:, ai_response:, processing_time:, force_update: false)
      # Extract model name from provider_info if available
      model_name = ai_response.dig(:provider_info, :model) || ai_response[:model] || "unknown"
      
      log_entry = {
        timestamp: Time.current.iso8601,
        event: "translation_completed",
        post_id: post_id,
        target_language: target_language,
        translation_id: translation_id,
        status: "success",
        force_update: force_update,
        processing_time_ms: processing_time,
        ai_model: model_name,
        ai_usage: ai_response.dig(:provider_info, :tokens_used) ? { tokens_used: ai_response.dig(:provider_info, :tokens_used) } : {},
        translated_length: ai_response[:translated_text]&.length || 0
      }
      
      write_log(log_entry)
    end
    
    def self.log_translation_error(post_id:, target_language:, error:, processing_time:)
      log_entry = {
        timestamp: Time.current.iso8601,
        event: "translation_failed",
        post_id: post_id,
        target_language: target_language,
        status: "error",
        error_message: error.message,
        error_class: error.class.name,
        processing_time_ms: processing_time
      }
      
      write_log(log_entry)
    end
    
    def self.log_translation_skipped(post_id:, target_language:, reason:)
      log_entry = {
        timestamp: Time.current.iso8601,
        event: "translation_skipped",
        post_id: post_id,
        target_language: target_language,
        status: "skipped",
        reason: reason
      }
      
      write_log(log_entry)
    end
    
    private
    
    def self.write_log(log_entry)
      # Ensure log directory exists
      FileUtils.mkdir_p(File.dirname(LOG_FILE_PATH))
      
      # Write log entry as JSON line
      File.open(LOG_FILE_PATH, "a") do |file|
        file.puts(JSON.generate(log_entry))
      end
    rescue => e
      Rails.logger.error("Failed to write translation log: #{e.message}")
    end
  end
end
