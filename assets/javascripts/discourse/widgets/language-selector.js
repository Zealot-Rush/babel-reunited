import { h } from "virtual-dom";
import { createWidget } from "discourse/widgets/widget";

/**
 * Language selector widget for choosing translation languages
 * @component language-selector
 * @param {Object} attrs - Widget attributes
 * @param {Array} attrs.availableLanguages - Available languages
 * @param {string} attrs.currentLanguage - Currently selected language
 * @param {Function} attrs.onLanguageSelect - Callback when language is selected
 */
export default createWidget("language-selector", {
  tagName: "div.ai-language-selector",

  buildKey: (attrs) =>
    `language-selector-${attrs.currentLanguage || "default"}`,

  defaultState() {
    return {
      isOpen: false,
      searchQuery: "",
    };
  },

  html(attrs, state) {
    return h("div.ai-language-selector-container", [
      this.renderTrigger(attrs, state),
      this.renderDropdown(attrs, state),
    ]);
  },

  renderTrigger(attrs, state) {
    const { currentLanguage } = attrs;
    const currentLang = this.getLanguageInfo(currentLanguage);

    return h(
      "button.btn.btn-secondary.ai-language-trigger",
      {
        onclick: () => this.toggleDropdown(),
      },
      [
        h("i.fa.fa-globe"),
        h(
          "span.ai-language-name",
          currentLang ? currentLang.name : "Select Language"
        ),
        h("i.fa", {
          className: state.isOpen ? "fa-chevron-up" : "fa-chevron-down",
        }),
      ]
    );
  },

  renderDropdown(attrs, state) {
    if (!state.isOpen) {
      return null;
    }

    const filteredLanguages = this.getFilteredLanguages(state.searchQuery);

    return h("div.ai-language-dropdown", [
      this.renderSearchInput(state),
      this.renderLanguageList(filteredLanguages, attrs),
    ]);
  },

  renderSearchInput(state) {
    return h("div.ai-language-search", [
      h("input.ai-language-search-input", {
        type: "text",
        placeholder: this.i18n(
          "js.divine_rapier_ai_translator.search_languages"
        ),
        value: state.searchQuery,
        oninput: (e) => this.updateSearchQuery(e.target.value),
      }),
      h("i.fa.fa-search.ai-search-icon"),
    ]);
  },

  renderLanguageList(languages, attrs) {
    return h("div.ai-language-list", [
      h(
        "div.ai-language-categories",
        this.getLanguageCategories().map((category) =>
          this.renderLanguageCategory(category, languages, attrs)
        )
      ),
    ]);
  },

  renderLanguageCategory(category, languages, attrs) {
    const categoryLanguages = languages.filter(
      (lang) => lang.category === category.name
    );

    if (categoryLanguages.length === 0) {
      return null;
    }

    return h("div.ai-language-category", [
      h("div.ai-language-category-header", [
        h("i.fa", { className: category.icon }),
        h("span", category.name),
      ]),
      h(
        "div.ai-language-category-items",
        categoryLanguages.map((lang) => this.renderLanguageItem(lang, attrs))
      ),
    ]);
  },

  renderLanguageItem(language, attrs) {
    const { currentLanguage } = attrs;
    const isSelected = currentLanguage === language.code;

    return h(
      "button.btn.ai-language-item",
      {
        className: isSelected ? "selected" : "",
        onclick: () => this.selectLanguage(language.code, attrs),
      },
      [
        h("span.ai-language-item-name", language.name),
        h("span.ai-language-item-code", language.code),
        isSelected && h("i.fa.fa-check.ai-selected-icon"),
      ]
    );
  },

  getLanguageInfo(code) {
    const allLanguages = this.getAllLanguages();
    return allLanguages.find((lang) => lang.code === code);
  },

  getFilteredLanguages(searchQuery) {
    const allLanguages = this.getAllLanguages();

    if (!searchQuery) {
      return allLanguages;
    }

    const query = searchQuery.toLowerCase();
    return allLanguages.filter(
      (lang) =>
        lang.name.toLowerCase().includes(query) ||
        lang.code.toLowerCase().includes(query) ||
        lang.nativeName.toLowerCase().includes(query)
    );
  },

  getLanguageCategories() {
    return [
      { name: "Popular", icon: "fa-star" },
      { name: "European", icon: "fa-globe-europe" },
      { name: "Asian", icon: "fa-globe-asia" },
      { name: "Other", icon: "fa-globe" },
    ];
  },

  getAllLanguages() {
    return [
      // Popular languages
      {
        code: "en",
        name: "English",
        nativeName: "English",
        category: "Popular",
      },
      { code: "zh", name: "Chinese", nativeName: "中文", category: "Popular" },
      {
        code: "ja",
        name: "Japanese",
        nativeName: "日本語",
        category: "Popular",
      },
      { code: "ko", name: "Korean", nativeName: "한국어", category: "Popular" },
      {
        code: "es",
        name: "Spanish",
        nativeName: "Español",
        category: "Popular",
      },
      {
        code: "fr",
        name: "French",
        nativeName: "Français",
        category: "Popular",
      },
      {
        code: "de",
        name: "German",
        nativeName: "Deutsch",
        category: "Popular",
      },
      {
        code: "ru",
        name: "Russian",
        nativeName: "Русский",
        category: "Popular",
      },

      // European languages
      {
        code: "pt",
        name: "Portuguese",
        nativeName: "Português",
        category: "European",
      },
      {
        code: "it",
        name: "Italian",
        nativeName: "Italiano",
        category: "European",
      },
      {
        code: "nl",
        name: "Dutch",
        nativeName: "Nederlands",
        category: "European",
      },
      {
        code: "sv",
        name: "Swedish",
        nativeName: "Svenska",
        category: "European",
      },
      {
        code: "no",
        name: "Norwegian",
        nativeName: "Norsk",
        category: "European",
      },
      { code: "da", name: "Danish", nativeName: "Dansk", category: "European" },
      {
        code: "fi",
        name: "Finnish",
        nativeName: "Suomi",
        category: "European",
      },
      {
        code: "pl",
        name: "Polish",
        nativeName: "Polski",
        category: "European",
      },
      {
        code: "cs",
        name: "Czech",
        nativeName: "Čeština",
        category: "European",
      },
      {
        code: "hu",
        name: "Hungarian",
        nativeName: "Magyar",
        category: "European",
      },

      // Asian languages
      { code: "hi", name: "Hindi", nativeName: "हिन्दी", category: "Asian" },
      { code: "ar", name: "Arabic", nativeName: "العربية", category: "Asian" },
      { code: "th", name: "Thai", nativeName: "ไทย", category: "Asian" },
      {
        code: "vi",
        name: "Vietnamese",
        nativeName: "Tiếng Việt",
        category: "Asian",
      },
      {
        code: "id",
        name: "Indonesian",
        nativeName: "Bahasa Indonesia",
        category: "Asian",
      },
      {
        code: "ms",
        name: "Malay",
        nativeName: "Bahasa Melayu",
        category: "Asian",
      },
      {
        code: "tl",
        name: "Filipino",
        nativeName: "Filipino",
        category: "Asian",
      },

      // Other languages
      { code: "he", name: "Hebrew", nativeName: "עברית", category: "Other" },
      { code: "tr", name: "Turkish", nativeName: "Türkçe", category: "Other" },
      {
        code: "uk",
        name: "Ukrainian",
        nativeName: "Українська",
        category: "Other",
      },
      {
        code: "bg",
        name: "Bulgarian",
        nativeName: "Български",
        category: "Other",
      },
      { code: "ro", name: "Romanian", nativeName: "Română", category: "Other" },
      { code: "el", name: "Greek", nativeName: "Ελληνικά", category: "Other" },
    ];
  },

  toggleDropdown() {
    this.state.isOpen = !this.state.isOpen;
    this.state.searchQuery = "";
    this.scheduleRerender();
  },

  updateSearchQuery(query) {
    this.state.searchQuery = query;
    this.scheduleRerender();
  },

  selectLanguage(languageCode, attrs) {
    const { onLanguageSelect } = attrs;

    if (onLanguageSelect) {
      onLanguageSelect(languageCode);
    }

    this.state.isOpen = false;
    this.state.searchQuery = "";
    this.scheduleRerender();
  },
});
