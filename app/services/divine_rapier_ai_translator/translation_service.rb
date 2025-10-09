# frozen_string_literal: true

require 'faraday'
require 'json'

module DivineRapierAiTranslator
  class TranslationService
    include Service::Base

    def initialize(post:, target_language:)
      @post = post
      @target_language = target_language
      super()
    end

    def call
      return context.fail(error: "Post not found") if @post.blank?
      return context.fail(error: "Target language not specified") if @target_language.blank?

      # Check if translation already exists
      existing_translation = PostTranslation.find_translation(@post.id, @target_language)
      if existing_translation.present?
        context[:translation] = existing_translation
        return context
      end

      # Prepare content for translation
      content_to_translate = prepare_content_for_translation(@post.raw)

      # Call OpenAI translation API
      translation_result = call_openai_api(content_to_translate, @target_language)

      if translation_result[:error]
        return context.fail(error: translation_result[:error])
      end

      # Save translation
      translation = create_translation(translation_result)
      context[:translation] = translation
      context
    end

    private

    def prepare_content_for_translation(raw_content)
      # Preserve markdown and HTML formatting
      # Remove any Discourse-specific formatting that might interfere
      raw_content
    end


    def call_openai_api(content, target_language)
      api_key = SiteSetting.divine_rapier_ai_translator_openai_api_key
      return { error: "OpenAI API key not configured" } if api_key.blank?

      # Check rate limit
      unless DivineRapierAiTranslator::RateLimiter.can_make_request?
        return { error: "Rate limit exceeded. Please try again later." }
      end

      # Check content length
      if content.length > SiteSetting.divine_rapier_ai_translator_max_content_length
        return { error: "Content too long for translation" }
      end

      # Prepare the prompt for translation
      prompt = build_translation_prompt(content, target_language)
      
      # Make API call
      response = make_openai_request(prompt, api_key)
      
      # Record the request for rate limiting
      DivineRapierAiTranslator::RateLimiter.record_request
      
      return { error: response[:error] } if response[:error]
      
      {
        translated_text: response[:translated_text],
        source_language: response[:source_language] || "auto",
        confidence: response[:confidence] || 0.95,
        provider_info: {
          model: response[:model] || "gpt-3.5-turbo",
          tokens_used: response[:tokens_used],
          provider: "openai"
        }
      }
    rescue => e
      Rails.logger.error("OpenAI API error: #{e.message}")
      { error: "Translation service temporarily unavailable" }
    end


    def create_translation(translation_result)
      PostTranslation.create!(
        post: @post,
        language: @target_language,
        translated_content: translation_result[:translated_text],
        source_language: translation_result[:source_language],
        translation_provider: "openai",
        metadata: {
          confidence: translation_result[:confidence],
          provider_info: translation_result[:provider_info],
          translated_at: Time.current
        }
      )
    end

    def build_translation_prompt(content, target_language)
      preserve_formatting = SiteSetting.divine_rapier_ai_translator_preserve_formatting
      
      if preserve_formatting
        <<~PROMPT
          Translate the following text to #{target_language}. 
          Preserve all markdown formatting, HTML tags, and Discourse-specific formatting.
          If the text is already in #{target_language}, return the original text unchanged.
          Only return the translated text, no explanations or additional content.
          
          Text to translate:
          #{content}
        PROMPT
      else
        <<~PROMPT
          Translate the following text to #{target_language}.
          If the text is already in #{target_language}, return the original text unchanged.
          Only return the translated text, no explanations or additional content.
          
          Text to translate:
          #{content}
        PROMPT
      end
    end

    def make_openai_request(prompt, api_key)
      # Support both OpenAI and OpenAI-compatible APIs
      base_url = determine_openai_base_url
      
      conn = Faraday.new(url: base_url) do |f|
        f.request :json
        f.response :json
        f.adapter Faraday.default_adapter
      end

      request_body = {
        model: SiteSetting.divine_rapier_ai_translator_model,
        messages: [
          {
            role: "user",
            content: prompt
          }
        ],
        max_tokens: 2000,
        temperature: 0.3
      }

      response = conn.post("/v1/chat/completions") do |req|
        req.headers['Authorization'] = "Bearer #{api_key}"
        req.headers['Content-Type'] = 'application/json'
        req.body = request_body.to_json
      end

      if response.success?
        parse_openai_response(response.body)
      else
        handle_openai_error(response)
      end
    rescue Faraday::Error => e
      Rails.logger.error("Faraday error: #{e.message}")
      { error: "Network error: #{e.message}" }
    end

    def determine_openai_base_url
      # Check if using a custom OpenAI-compatible API
      custom_url = SiteSetting.divine_rapier_ai_translator_openai_base_url
      return custom_url if custom_url.present?
      
      "https://api.openai.com"
    end

    def parse_openai_response(response_body)
      choices = response_body.dig("choices")
      return { error: "Invalid response format" } unless choices&.any?

      translated_text = choices.first.dig("message", "content")
      return { error: "No translation in response" } if translated_text.blank?

      {
        translated_text: translated_text.strip,
        source_language: "auto",
        confidence: 0.95,
        model: response_body.dig("model"),
        tokens_used: response_body.dig("usage", "total_tokens")
      }
    end

    def handle_openai_error(response)
      error_body = response.body
      error_message = error_body.dig("error", "message") || "Unknown API error"
      
      case response.status
      when 401
        { error: "Invalid API key" }
      when 429
        { error: "Rate limit exceeded. Please try again later." }
      when 400
        { error: "Bad request: #{error_message}" }
      when 500..599
        { error: "OpenAI service temporarily unavailable" }
      else
        { error: "API error: #{error_message}" }
      end
    end

  end
end
