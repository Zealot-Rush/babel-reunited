# AI Translator Frontend Components

This plugin provides several frontend components for displaying and managing post translations in Discourse.

## Components

### 1. Translation Widget (`translation-widget`)
A comprehensive widget that displays all available translations for a post and allows users to:
- View different language versions
- Create new translations
- Delete existing translations
- Switch between original and translated content

### 2. Translation Button (`translation-button`)
A quick action button that provides:
- Fast translation to popular languages
- Visual indication when translations exist
- Quick language selection dropdown

### 3. Language Selector (`language-selector`)
A sophisticated language picker with:
- Categorized language options (Popular, European, Asian, Other)
- Search functionality
- Native language names
- Visual indicators for available translations

### 4. Translation Display (`translation-display`)
A content display component that shows:
- Tabbed interface for different languages
- Original vs translated content switching
- Translation metadata (provider, confidence, date)
- Translation management actions

## Integration

The components are automatically integrated into Discourse posts through:

1. **Post Serializer Extensions**: Added `available_translations` and `post_translations` to post data
2. **Widget Registration**: All components are registered with Discourse's widget system
3. **Post Integration**: Components are automatically attached to posts when translations exist
4. **API Service**: Translation API service handles all backend communication

## Usage

### For Users
- Translation buttons appear automatically on posts when the plugin is enabled
- Click the translate button to create new translations
- Use the language tabs to switch between different versions
- Delete translations using the delete button in each translation

### For Developers
The components can be used in custom themes or plugins:

```javascript
// Attach translation widget to any element
this.attach("translation-widget", {
  postId: post.id,
  availableTranslations: post.available_translations,
  postTranslations: post.post_translations
});

// Use translation API service
const translationApi = this.container.lookup("service:translation-api");
const translations = await translationApi.getTranslations(postId);
```

## Styling

The components use Discourse's CSS variables and follow the platform's design patterns:
- Responsive design for mobile and desktop
- Dark mode support
- Consistent with Discourse's UI components
- Customizable through CSS variables

## API Endpoints

The frontend components communicate with these backend endpoints:
- `GET /ai-translator/posts/:id/translations` - Get all translations
- `GET /ai-translator/posts/:id/translations/:language` - Get specific translation
- `POST /ai-translator/posts/:id/translations` - Create new translation
- `DELETE /ai-translator/posts/:id/translations/:language` - Delete translation

## Configuration

The components respect these site settings:
- `divine_rapier_ai_translator_enabled` - Enable/disable the plugin
- `divine_rapier_ai_translator_auto_translate_languages` - Languages for auto-translation
- `divine_rapier_ai_translator_openai_api_key` - API key for translation service

## Browser Support

The components work in all modern browsers that support:
- ES6 modules
- CSS Grid and Flexbox
- Fetch API
- CSS Custom Properties (CSS Variables)

