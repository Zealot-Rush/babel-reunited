# frozen_string_literal: true

DivineRapierAiTranslator::Engine.routes.draw do
  resources :posts, only: [] do
    resources :translations, only: [:index, :show, :create, :destroy]
  end

  # User preference routes
  get "user-preferred-language", to: "translations#get_user_preferred_language"
  post "user-preferred-language", to: "translations#set_user_preferred_language"

  namespace :admin do
    get "/" => "admin#index"
    get "/stats" => "admin#stats"
  end
end
