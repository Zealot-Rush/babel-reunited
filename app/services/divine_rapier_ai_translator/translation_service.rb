# frozen_string_literal: true

require "faraday"
require "json"

module BabelReunited
  class TranslationService
    include Service::Base

    def initialize(post:, target_language:, force_update: false)
      @post = post
      @target_language = target_language
      @force_update = force_update
      super()
    end

    def call
      return context.fail(error: "Post not found") if @post.blank?
      return context.fail(error: "Target language not specified") if @target_language.blank?

      # Prepare content for translation
      content_to_translate = prepare_content_for_translation(@post.cooked)
      
      # Prepare title for translation (only for first post)
      title_to_translate = prepare_title_for_translation

      # Call OpenAI translation API
      translation_result = call_openai_api(content_to_translate, @target_language, title_to_translate)

      # Fallback: if title was requested but missing, translate title with a lightweight prompt
      if title_to_translate.present? && translation_result.is_a?(Hash) && translation_result[:translated_title].nil?
        begin
          api_config = get_api_config
          if api_config[:error]
            Rails.logger.warn("Skipping title fallback due to api_config error: #{api_config[:error]}")
          else
            fallback_title = translate_title_fallback(title_to_translate, @target_language, api_config)
            translation_result[:translated_title] = fallback_title if fallback_title.present?
          end
        rescue => e
          Rails.logger.warn("Title fallback translation failed: #{e.message}")
        end
      end

      return context.fail(error: translation_result[:error]) if translation_result[:error]

      # Create translation result object (not saved to database yet)
      translation = create_translation_result(translation_result)
      context[:translation] = translation
      context[:ai_response] = translation_result # Add AI response to context for logging
      context
    end

    private

    def prepare_content_for_translation(cooked_content)
      # Use cooked HTML content for translation
      # This preserves all formatting, links, and Discourse-specific elements
      cooked_content
    end

    def prepare_title_for_translation
      # Only translate title for the first post of a topic
      return nil unless @post.post_number == 1
      return nil if @post.topic.title.blank?
      return nil unless SiteSetting.babel_reunited_translate_title
      
      @post.topic.title
    end

    def call_openai_api(content, target_language, title = nil)
      api_config = get_api_config
      return { error: api_config[:error] } if api_config[:error]

      # Check rate limit
      unless BabelReunited::RateLimiter.can_make_request?
        return { error: "Rate limit exceeded. Please try again later." }
      end

      # Check content length (include title in length calculation)
      total_length = content.length
      total_length += title.length if title.present?
      
      if total_length > SiteSetting.babel_reunited_max_content_length
        return { error: "Content too long for translation" }
      end

      # Prepare the prompt for translation
      prompt = build_translation_prompt(content, target_language, title)

      # Make API call
      response = make_openai_request(prompt, api_config)

      # Record the request for rate limiting
      BabelReunited::RateLimiter.record_request

      return { error: response[:error] } if response[:error]

      {
        translated_text: response[:translated_text],
        translated_title: response[:translated_title],
        source_language: response[:source_language] || "auto",
        confidence: response[:confidence] || 0.95,
        provider_info: {
          model: response[:model] || api_config[:model],
          tokens_used: response[:tokens_used],
          provider: api_config[:provider],
        },
      }
    rescue => e
      Rails.logger.error("OpenAI API error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
      BabelReunited::TranslationLogger.log_translation_error(
        post_id: @post&.id,
        target_language: @target_language,
        error: e,
        processing_time: 0,
        context: { phase: "call_openai_api_exception" }
      )
      { error: "Translation service temporarily unavailable" }
    end

    def create_translation_result(translation_result)
      # Create a temporary translation object with the translated content
      # This will be used by the job to update the actual database record
      OpenStruct.new(
        translated_content: translation_result[:translated_text],
        translated_title: translation_result[:translated_title],
        source_language: translation_result[:source_language],
      )
    end

    def create_or_update_translation(translation_result, existing_translation)
      if existing_translation.present?
        # Update existing translation
        existing_translation.update!(
          translated_content: translation_result[:translated_text],
          translated_title: translation_result[:translated_title],
          source_language: translation_result[:source_language],
          translation_provider: "openai",
          metadata: {
            confidence: translation_result[:confidence],
            provider_info: translation_result[:provider_info],
            translated_at: Time.current,
            updated_at: Time.current,
          },
        )
        existing_translation
      else
        # Create new translation
        create_translation(translation_result)
      end
    end

    def create_translation(translation_result)
      PostTranslation.create!(
        post: @post,
        language: @target_language,
        translated_content: translation_result[:translated_text],
        translated_title: translation_result[:translated_title],
        source_language: translation_result[:source_language],
        translation_provider: "openai",
        metadata: {
          confidence: translation_result[:confidence],
          provider_info: translation_result[:provider_info],
          translated_at: Time.current,
        },
      )
    end

    def build_translation_prompt(content, target_language, title = nil)
      preserve_formatting = SiteSetting.babel_reunited_preserve_formatting
      
      if title.present?
        # Include title in translation prompt
        title_instruction = <<~TITLE_INSTRUCTION
          
          IMPORTANT: This post is the first post of a topic. Please also translate the topic title.
          Topic title: #{title}
          
          Return your response in the following JSON format:
          {
            "translated_content": "translated HTML content here",
            "translated_title": "translated title here"
          }
          Requirements for JSON values:
          - translated_content MUST be pure HTML (no Markdown code fences like ``` or ```html)
          - Do NOT include document wrappers like <html>, <head>, or <body>
          - Do NOT add any extra text outside the HTML
        TITLE_INSTRUCTION
      else
        title_instruction = ""
      end

      if preserve_formatting
        <<~PROMPT
          Translate the following HTML content to #{target_language}. 
          
          CRITICAL REQUIREMENTS:
          - The input is HTML content with links, formatting, and Discourse-specific elements
          - Translate ONLY the text content, NOT the HTML tags or attributes
          - Preserve ALL HTML tags exactly as they are (including <a>, <p>, <div>, <span>, etc.)
          - Keep ALL href attributes and URLs unchanged
          - Maintain ALL CSS classes and IDs
          - Preserve ALL line breaks and whitespace structure
          - Do NOT modify any HTML structure or attributes
          - Do NOT add or remove any HTML tags
          - Do NOT change any links or URLs
          - Do NOT wrap the output in Markdown code fences (e.g., ``` or ```html)
          - Do NOT include document-level wrappers like <html>, <head>, or <body>
          
          The output should be valid HTML with the EXACT same structure as the input, only with translated text content.
          
          If the text is already in #{target_language}, return the original HTML unchanged.
          Only return the translated HTML, no explanations or additional content.
          #{title_instruction}
          
          HTML content to translate:
          #{content}
        PROMPT
      else
        <<~PROMPT
          Translate the following HTML content to #{target_language}.
          
          IMPORTANT:
          - The input is HTML content with links and formatting
          - Translate ONLY the text content, NOT the HTML tags or attributes
          - Preserve ALL HTML tags, href attributes, and URLs exactly as they are
          - Do NOT modify any HTML structure or links
          - Do NOT wrap the output in Markdown code fences (e.g., ``` or ```html)
          - Do NOT include document-level wrappers like <html>, <head>, or <body>
          
          If the text is already in #{target_language}, return the original HTML unchanged.
          Only return the translated HTML, no explanations or additional content.
          #{title_instruction}
          
          HTML content to translate:
          #{content}
        PROMPT
      end
    end

    def get_api_config
      config = BabelReunited::ModelConfig.get_config
      return { error: "Invalid preset model: #{SiteSetting.babel_reunited_preset_model}" } if config.nil?

      api_key = config[:api_key]
      return { error: "API key not configured for provider #{config[:provider]}" } if api_key.blank?

      base_url = config[:base_url]
      return { error: "Base URL not configured for provider #{config[:provider]}" } if base_url.blank?

      model_name = config[:model_name]
      return { error: "Model name not configured for provider #{config[:provider]}" } if model_name.blank?

      {
        api_key: api_key,
        base_url: base_url,
        model: model_name,
        max_tokens: config[:max_output_tokens] || config[:max_tokens] || SiteSetting.babel_reunited_custom_max_output_tokens,
        provider: config[:provider]
      }
    end

    def make_openai_request(prompt, api_config)
      conn =
        Faraday.new(url: api_config[:base_url]) do |f|
          f.request :json
          f.response :json
          f.adapter Faraday.default_adapter
        end

      request_body = {
        model: api_config[:model],
        messages: [{ role: "user", content: prompt }],
        max_tokens: api_config[:max_tokens],
        temperature: 0.3,
      }

      response =
        conn.post("/v1/chat/completions") do |req|
          req.headers["Authorization"] = "Bearer #{api_config[:api_key]}"
          req.headers["Content-Type"] = "application/json"
          req.body = request_body.to_json
        end

      # Always log provider HTTP response for diagnostics
      begin
        body_for_log =
          case response.body
          when String
            response.body
          else
            begin
              JSON.generate(response.body)
            rescue
              response.body.to_s
            end
          end

        BabelReunited::TranslationLogger.log_provider_response(
          post_id: @post&.id,
          target_language: @target_language,
          status: response.status,
          body: body_for_log[0, 4000],
          phase: "post_chat_completions",
          provider: api_config[:provider]
        )
      rescue => _
        # best-effort logging only
      end

      if response.success?
        result = parse_openai_response(response.body)
        if result.is_a?(Hash) && result[:error]
          begin
            body_for_log =
              case response.body
              when String
                response.body
              else
                begin
                  JSON.generate(response.body)
                rescue
                  response.body.to_s
                end
              end

            BabelReunited::TranslationLogger.log_translation_error(
              post_id: @post&.id,
              target_language: @target_language,
              error: StandardError.new(result[:error]),
              processing_time: 0,
              context: {
                phase: "provider_success_invalid_payload",
                provider_status: response.status,
                provider_body: body_for_log[0, 4000]
              }
            )
          rescue => _
            # best-effort logging
          end
        end
        result
      else
        handle_openai_error(response)
      end
    rescue Faraday::Error => e
      Rails.logger.error("Faraday error: #{e.message}")
      BabelReunited::TranslationLogger.log_translation_error(
        post_id: @post&.id,
        target_language: @target_language,
        error: e,
        processing_time: 0,
        context: { phase: "faraday_exception" }
      )
      { error: "Network error: #{e.message}" }
    end

    def translate_title_fallback(title, target_language, api_config)
      conn =
        Faraday.new(url: api_config[:base_url]) do |f|
          f.request :json
          f.response :json
          f.adapter Faraday.default_adapter
        end

      prompt = <<~P
        Translate the following text to #{target_language}.
        Return ONLY the translated text, no quotes, no extra words.

        Text:
        #{title}
      P

      request_body = {
        model: api_config[:model],
        messages: [{ role: "user", content: prompt }],
        max_tokens: [128, api_config[:max_tokens].to_i].min,
        temperature: 0.2,
      }

      response =
        conn.post("/v1/chat/completions") do |req|
          req.headers["Authorization"] = "Bearer #{api_config[:api_key]}"
          req.headers["Content-Type"] = "application/json"
          req.body = request_body.to_json
        end

      if response.success?
        content = response.body.dig("choices", 0, "message", "content")
        return content.to_s.strip if content.present?
      end

      nil
    rescue => e
      Rails.logger.warn("translate_title_fallback error: #{e.message}")
      nil
    end

    def parse_openai_response(response_body)
      choices = response_body.dig("choices")
      return { error: "Invalid response format" } unless choices&.any?

      response_content = choices.first.dig("message", "content")
      return { error: "No translation in response" } if response_content.blank?

      cleaned_content = response_content.strip
      
      # Try multiple approaches to parse JSON
      parsed_result = try_parse_json_response(cleaned_content)
      
      if parsed_result
        parsed_result.merge({
          source_language: "auto",
          confidence: 0.95,
          model: response_body.dig("model"),
          tokens_used: response_body.dig("usage", "total_tokens"),
        })
      else
        # Fallback to plain text response
        {
          translated_text: cleaned_content,
          translated_title: nil,
          source_language: "auto",
          confidence: 0.95,
          model: response_body.dig("model"),
          tokens_used: response_body.dig("usage", "total_tokens"),
        }
      end
    end

    def try_parse_json_response(content)
      # Method 1: Try to find complete JSON object
      json_match = content.match(/\{.*?\}/m)
      if json_match
        begin
          parsed = JSON.parse(json_match[0])
          if parsed["translated_content"].present?
            Rails.logger.info("Successfully parsed JSON response with translated_content")
            return {
              translated_text: parsed["translated_content"],
              translated_title: parsed["translated_title"]
            }
          end
        rescue JSON::ParserError => e
          Rails.logger.warn("JSON parsing failed: #{e.message}")
        end
      end

      # Method 2: Try to find JSON that starts with translated_content
      if content.include?('"translated_content"')
        begin
          # Try to extract JSON starting from translated_content
          json_start = content.index('{')
          if json_start
            json_part = content[json_start..-1]
            # Try to find the end of the JSON
            brace_count = 0
            json_end = -1
            json_part.chars.each_with_index do |char, index|
              if char == '{'
                brace_count += 1
              elsif char == '}'
                brace_count -= 1
                if brace_count == 0
                  json_end = index
                  break
                end
              end
            end
            
            if json_end > 0
              complete_json = json_part[0..json_end]
              parsed = JSON.parse(complete_json)
              if parsed["translated_content"].present?
                Rails.logger.info("Successfully parsed JSON response using brace counting")
                return {
                  translated_text: parsed["translated_content"],
                  translated_title: parsed["translated_title"]
                }
              end
            else
              # JSON is incomplete, try to extract translated_content manually
              Rails.logger.warn("JSON appears to be incomplete, attempting manual extraction")
              return extract_from_incomplete_json(json_part)
            end
          end
        rescue JSON::ParserError => e
          Rails.logger.warn("Brace counting JSON parsing failed: #{e.message}")
        end
      end

      nil
    end

    def extract_from_incomplete_json(json_part)
      # Try to extract translated_content from incomplete JSON
      content_match = json_part.match(/"translated_content":\s*"([^"]*(?:\\.[^"]*)*)"/m)
      if content_match
        translated_content = content_match[1]
        # Unescape JSON string
        translated_content = translated_content.gsub('\\"', '"').gsub('\\n', "\n").gsub('\\\\', '\\')
        
        Rails.logger.info("Successfully extracted translated_content from incomplete JSON")
        return {
          translated_text: translated_content,
          translated_title: nil # Can't extract title from incomplete JSON
        }
      end
      
      nil
    end

    def handle_openai_error(response)
      raw_body = response.body
      parsed_body =
        begin
          if raw_body.is_a?(String)
            JSON.parse(raw_body)
          else
            raw_body
          end
        rescue JSON::ParserError
          nil
        end

      error_message =
        if parsed_body.is_a?(Hash)
          error_field = parsed_body["error"]
          nested_error_message = error_field.is_a?(Hash) ? error_field["message"] : nil
          nested_error_message || parsed_body["message"] || error_field || "Unknown API error"
        else
          raw_body.to_s.presence || "Unknown API error"
        end

      # Log provider error details to ai_translation.log for diagnostics
      begin
        BabelReunited::TranslationLogger.log_translation_error(
          post_id: @post&.id,
          target_language: @target_language,
          error: StandardError.new(error_message),
          processing_time: 0,
          context: {
            phase: "provider_error",
            provider_status: response.status,
            provider_body: raw_body.to_s[0, 4000], # truncate to avoid huge logs
          }
        )
      rescue => _
        # best-effort logging only
      end

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
