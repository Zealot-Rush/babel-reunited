import { withPluginApi } from "discourse/lib/plugin-api";
import Component from "@glimmer/component";
import DivineRapierTestBox from "../components/divine-rapier-test-box";

/**
 * Initialize translation widgets and components
 * This initializer registers all translation-related widgets and components
 */
export default {
  name: "divine-rapier-ai-translator-widgets",

  initialize() {
    console.log("🚀 Divine Rapier AI Translator widgets initializer loaded!");

    withPluginApi("0.8.7", (api) => {
      console.log("✅ Plugin API loaded for Divine Rapier AI Translator");

      // 使用新的 Glimmer 系统在每个post之前插入testBox
      api.renderBeforeWrapperOutlet("post-article", DivineRapierTestBox);

      // Add translation components to post display
      api.addPostClassesCallback((attrs) => {
        console.log("🔍 DEBUG: addPostClassesCallback called with attrs:", attrs);
        if (attrs.show_translation_widget || attrs.show_translation_button) {
          console.log("✅ DEBUG: Adding 'has-translations' class");
          return "has-translations";
        }
        console.log("❌ DEBUG: No translation classes to add");
      });

      // Use modern Glimmer component approach
      customizeGlimmerPost(api);

      // Add keyboard shortcuts for translation
      api.addKeyboardShortcut("t", "translatePost", {
        help: "js.divine_rapier_ai_translator.translate_shortcut"
      });
      
      console.log("✅ DEBUG: Initializer setup complete with official method");
    });
  }
};

function customizeGlimmerPost(api) {
  console.log("Setting up modern Glimmer post stream integration");
  
  // Use the modern approach for adding components to posts
  api.modifyClass("component:post", {
    pluginId: "divine-rapier-ai-translator",
    
    didInsertElement() {
      console.log("🔍 DEBUG: Post component didInsertElement called");
      this._super(...arguments);
      this._attachTranslationWidget();
    },
    
    _attachTranslationWidget() {
      console.log("🔍 DEBUG: _attachTranslationWidget called");
      const post = this.args.post;
      
      if (!post) {
        console.log("❌ DEBUG: No post found, returning");
        return;
      }

      console.log("🔍 DEBUG: Post ID:", post.id);
      console.log("🔍 DEBUG: Post show_translation_widget:", post.show_translation_widget);
      console.log("🔍 DEBUG: Post show_translation_button:", post.show_translation_button);
      console.log("🔍 DEBUG: Post post_translations:", post.post_translations);
      
      // 检查是否有翻译数据
      if (post.post_translations && post.post_translations.length > 0) {
        console.log("✅ DEBUG: Found translations, creating debug box");
        this._createTranslationDebugBox(post);
      } else {
        console.log("❌ DEBUG: No translations found");
      }
    },
    
    _createTranslationDebugBox(post) {
      // 创建调试框
      const debugBox = document.createElement("div");
      debugBox.style.cssText = `
        margin: 20px 0;
        padding: 15px;
        background: #f0f8ff;
        border: 2px solid #007bff;
        border-radius: 8px;
        font-family: Arial, sans-serif;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
      `;
      
      debugBox.innerHTML = `
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 15px;">
          <h3 style="margin: 0; color: #007bff; font-size: 18px;">
            🔍 Translation Debug Box (Post ${post.id})
          </h3>
          <button id="debug-toggle-${post.id}" style="background: #007bff; color: white; border: none; padding: 5px 10px; border-radius: 4px; cursor: pointer;">
            Toggle Details
          </button>
        </div>
        
        <div id="debug-summary-${post.id}">
          <p><strong>Original Content:</strong> ${post.raw ? post.raw.substring(0, 100) + '...' : 'No content'}</p>
          <p><strong>Available Translations:</strong> ${post.available_translations ? post.available_translations.join(', ') : 'None'}</p>
          <p><strong>Translation Count:</strong> ${post.post_translations ? post.post_translations.length : 0}</p>
        </div>
        
        <div id="debug-details-${post.id}" style="display: none; margin-top: 15px;">
          <h4 style="color: #007bff; margin-bottom: 10px;">Translation Details:</h4>
          ${this._renderTranslationDetails(post.post_translations)}
        </div>
      `;
      
      // 添加到post元素后面
      const postElement = this.element.querySelector(".post");
      if (postElement) {
        console.log("✅ DEBUG: Found post element, appending debug box");
        postElement.appendChild(debugBox);
        
        // 添加切换按钮事件
        const toggleButton = document.getElementById(`debug-toggle-${post.id}`);
        const detailsDiv = document.getElementById(`debug-details-${post.id}`);
        
        toggleButton.addEventListener("click", () => {
          if (detailsDiv.style.display === "none") {
            detailsDiv.style.display = "block";
            toggleButton.textContent = "Hide Details";
          } else {
            detailsDiv.style.display = "none";
            toggleButton.textContent = "Toggle Details";
          }
        });
      } else {
        console.log("❌ DEBUG: No post element found");
      }
    },
    
    _renderTranslationDetails(translations) {
      if (!translations || translations.length === 0) {
        return "<p>No translations available</p>";
      }
      
      return translations.map((translation, index) => `
        <div style="margin-bottom: 15px; padding: 10px; background: white; border-radius: 4px; border-left: 4px solid #007bff;">
          <h5 style="margin: 0 0 8px 0; color: #007bff;">Translation ${index + 1}</h5>
          <p><strong>Language:</strong> ${translation.language}</p>
          <p><strong>Provider:</strong> ${translation.translation_provider || 'Unknown'}</p>
          <p><strong>Confidence:</strong> ${translation.confidence || 'N/A'}%</p>
          <p><strong>Created:</strong> ${translation.created_at || 'Unknown'}</p>
          <div style="margin-top: 8px;">
            <strong>Translated Content:</strong>
            <div style="background: #f8f9fa; padding: 8px; border-radius: 4px; margin-top: 4px; max-height: 200px; overflow-y: auto;">
              ${translation.translated_content || 'No content'}
            </div>
          </div>
        </div>
      `).join('');
    }
  });
}