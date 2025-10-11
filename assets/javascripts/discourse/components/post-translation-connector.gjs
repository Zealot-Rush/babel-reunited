import Component from "@glimmer/component";
import TranslationWidget from "./translation-widget";
import TranslationButton from "./translation-button";

/**
 * Translation connector component for post content
 * @component PostTranslationConnector
 * @param {Object} post - The post object with translation data
 */
export default class PostTranslationConnector extends Component {
  static shouldRender(args) {
    return args.post?.show_translation_widget;
  }

  <template>
    <div class="post-translation-integration">
      <div class="post-translation-container">
        {{#if @post.show_translation_button}}
          <div class="post-translation-button-wrapper">
            <TranslationButton 
              @postId={{@post.id}}
              @availableTranslations={{@post.available_translations}} 
            />
          </div>
        {{/if}}
        {{#if @post.show_translation_widget}}
          <div class="post-translation-widget-wrapper">
            <TranslationWidget 
              @postId={{@post.id}}
              @availableTranslations={{@post.available_translations}}
              @postTranslations={{@post.post_translations}}
              @originalContent={{@post.raw}}
            />
          </div>
        {{/if}}
      </div>
    </div>
  </template>
}
