# Divine Rapier AI Translator

AI-powered post translation plugin for Discourse that automatically translates posts to multiple languages using third-party AI APIs.

## Features

- **Automatic Translation**: Automatically translates posts when created or edited
- **OpenAI Integration**: Full support for OpenAI and OpenAI-compatible APIs
- **Format Preservation**: Preserves markdown and HTML formatting during translation
- **Language Detection**: Automatic source language detection by AI providers
- **Batch Processing**: Efficient batch translation with rate limiting
- **RESTful API**: Complete API for managing translations
- **Admin Interface**: Easy configuration through Discourse admin panel

## Installation

1. Add the plugin to your Discourse instance
2. Run database migrations: `bundle exec rake db:migrate`
3. Enable the plugin in Admin > Plugins
4. Configure your AI API keys in Admin > Settings

## Configuration

### Site Settings

- `divine_rapier_ai_translator_enabled`: Enable/disable the plugin
- `divine_rapier_ai_translator_model`: OpenAI model to use for translation (e.g., gpt-3.5-turbo, gpt-4)
- `divine_rapier_ai_translator_auto_translate_languages`: Comma-separated list of languages for auto-translation
- `divine_rapier_ai_translator_openai_api_key`: OpenAI API key
- `divine_rapier_ai_translator_openai_base_url`: Custom OpenAI-compatible API URL (optional)
- `divine_rapier_ai_translator_rate_limit_per_minute`: Rate limiting for API calls
- `divine_rapier_ai_translator_max_content_length`: Maximum content length for translation
- `divine_rapier_ai_translator_preserve_formatting`: Preserve markdown/HTML formatting

### Supported Languages

The plugin supports all languages supported by OpenAI. Use standard language codes (e.g., `en`, `es`, `fr`, `de`, `zh-CN`).

## API Usage

### Get Post Translations

```http
GET /ai-translator/posts/{post_id}/translations
```

### Get Specific Translation

```http
GET /ai-translator/posts/{post_id}/translations/{language}
```

### Create Translation

```http
POST /ai-translator/posts/{post_id}/translations
Content-Type: application/json

{
  "target_language": "es",
  "provider": "openai"
}
```

### Delete Translation

```http
DELETE /ai-translator/posts/{post_id}/translations/{language}
```

## Database Schema

The plugin creates a `post_translations` table with the following structure:

- `id`: Primary key
- `post_id`: Foreign key to posts table
- `language`: Target language code
- `translated_content`: Translated content
- `source_language`: Detected source language
- `translation_provider`: AI provider used
- `metadata`: Additional metadata (confidence, tokens used, etc.)
- `created_at`: Creation timestamp
- `updated_at`: Last update timestamp

## Development

### Running Tests

```bash
# Ruby tests
LOAD_PLUGINS=1 bin/rspec plugins/divine-rapier-ai-translator/spec

# JavaScript tests
LOAD_PLUGINS=1 bin/rake qunit:test
```

### Linting

```bash
bin/lint plugins/divine-rapier-ai-translator
```

## License

MIT License

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## Support

For support and questions, please open an issue on GitHub.
