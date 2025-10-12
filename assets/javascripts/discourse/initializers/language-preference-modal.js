import { withPluginApi } from "discourse/lib/plugin-api"
import LanguagePreferenceModal from "discourse/plugins/divine-rapier-ai-translator/discourse/components/modal/language-preference"

export default {
  initialize() {
    withPluginApi("0.8.7", (api) => {
      const currentUser = api.getCurrentUser()

      if (!currentUser) {
        console.log("Language Preference Modal: No current user found")
        return
      }

      console.log("Language Preference Modal: Initializing for user", currentUser.username, "ID:", currentUser.id)

      // Listen for MessageBus messages about language preference prompts
      api.onPageChange(() => {
        const messageBus = api.container.lookup("service:message-bus")
        const modal = api.container.lookup("service:modal")

        if (!messageBus || !modal) {
          return
        }

        // Subscribe to language preference prompt messages
        messageBus.subscribe(`/language-preference-prompt/${currentUser.id}`, (data) => {
          console.log("Language Preference Modal: MessageBus message received", data)

          // Check if user already has a preferred language
          if (currentUser.user_preferred_language) {
            console.log("Language Preference Modal: User already has language preference")
            return
          }

          // Check if modal was already shown in this session
          const modalShown = sessionStorage.getItem("language_preference_modal_shown")
          if (modalShown) {
            console.log("Language Preference Modal: Modal already shown in this session")
            return
          }

          console.log("Language Preference Modal: Showing modal via MessageBus")

          // Show the modal after a short delay to ensure page is loaded
          setTimeout(() => {
            modal.show(LanguagePreferenceModal)
          }, 1000)
        })
      })

       // Also check on initial page load
       api.onPageChange(async () => {
         const currentUser = api.getCurrentUser()
         console.log("Language Preference Modal: Current user", currentUser) 
         const modal = api.container.lookup("service:modal")

         if (!currentUser || !modal) {
           console.log("Language Preference Modal: Missing currentUser or modal service")
           return
         }

         console.log("Language Preference Modal: Checking on page change for user", currentUser.preferred_language)
         console.log("Language Preference Modal: User preferred language:", currentUser.preferred_language)
         console.log("Language Preference Modal: User preferred language enabled:", currentUser.preferred_language_enabled)
         if (currentUser.preferred_language_enabled === false) {
           console.log("Language Preference Modal: User preferred language is disabled")
           return
         }

         // Check if user already has a preferred language
         if (currentUser.preferred_language) {
           console.log("Language Preference Modal: User already has language preference:", currentUser.preferred_language)
           return
         }

         // Show the modal after a delay
         setTimeout(() => {
           console.log("Language Preference Modal: Attempting to show modal")
           modal.show(LanguagePreferenceModal)
         }, 1000)
       })
    })
  },
}
