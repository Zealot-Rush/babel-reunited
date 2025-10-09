# frozen_string_literal: true

DivineRapierAiTranslator::Engine.routes.draw do
  resources :posts, only: [] do
    resources :translations, only: [:index, :show, :create, :destroy]
  end

  namespace :admin do
    get "/" => "admin#index"
    get "/stats" => "admin#stats"
  end
end
