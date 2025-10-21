import Component from "@glimmer/component";

/**
 * Translated title component for topic lists
 * Shows translated title after the original topic link
 */
export default class TopicListAfterTitleTranslatedComponent extends Component {
  constructor() {
    super(...arguments);
    console.log(
      "🔍 TopicListAfterTitleTranslatedComponent constructor:",
      this.args
    );
  }

  get topic() {
    const topic = this.args.topic;
    console.log("🔍 Topic object:", topic);
    return topic;
  }

  get translatedTitle() {
    const translatedTitle = this.topic?.translated_title;
    console.log("🔍 Translated title:", translatedTitle);
    return translatedTitle;
  }

  get shouldShowTranslatedTitle() {
    const shouldShow =
      this.topic &&
      this.translatedTitle &&
      this.translatedTitle !== this.topic.title &&
      this.translatedTitle.length > 0;
    console.log("🔍 Should show translated title:", shouldShow);
    return shouldShow;
  }

  get topicUrl() {
    return this.topic?.url;
  }

  <template>
    {{#if this.shouldShowTranslatedTitle}}
      <div>
        <span
          class="ai-translated-title-after"
          style="margin-left: 8px; font-size: 11px; color: #666;"
        >
          <a
            href={{this.topicUrl}}
            data-topic-id={{this.topic.id}}
            class="translated-title-link"
            style="font-style: italic; color: #999; text-decoration: none;"
          >
            {{this.translatedTitle}}
          </a>
        </span>
      </div>
    {{/if}}
  </template>
}
