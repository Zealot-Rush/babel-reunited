import Component from "@glimmer/component";

/**
 * Test Box Component for Divine Rapier AI Translator
 * This component displays a test box before each post using the new Glimmer system
 */
export default class DivineRapierTestBox extends Component {
  get postInfo() {
    const post = this.args.post;
    return {
      id: post.id,
      number: post.post_number,
      username: post.username,
      createdAt: post.created_at
    };
  }

  <template>
    <div class="divine-rapier-test-box" style="
      margin: 20px 0;
      padding: 15px;
      background: #ff0000;
      color: #ffffff;
      border: 2px solid #000000;
      border-radius: 8px;
      font-family: Arial, sans-serif;
      font-size: 14px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.3);
    ">
      <div style="font-weight: bold; margin-bottom: 10px;">
        🚨 Divine Rapier AI Translator Test Box (Glimmer Method)
      </div>
      <div>Post ID: {{this.postInfo.id}}</div>
      <div>Post Number: {{this.postInfo.number}}</div>
      <div>Author: {{this.postInfo.username}}</div>
      <div style="margin-top: 10px; font-size: 12px;">
        Created: {{this.postInfo.createdAt}}
      </div>
      <div style="margin-top: 10px; font-size: 12px;">
        Method: renderBeforeWrapperOutlet (Glimmer)
      </div>
    </div>
  </template>
}
