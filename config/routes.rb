Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :auth do
      post "otp/request", to: "otps#request_otp"
      post "otp/verify",  to: "otps#verify_otp"
    end

    delete "logout", to: "sessions#destroy"

    get "me", to: "users#me"
    patch "me", to: "users#update_me"
    get "users/search", to: "users#search"

    # Conversations
    get "conversations", to: "conversations#index"
    post "conversations", to: "conversations#create"
    get "conversations/:id", to: "conversations#show"
    post "conversations/:id/read", to: "conversations#read"

    # Messages
    get "conversations/:id/messages", to: "messages#index"
    post "conversations/:id/messages", to: "messages#create"
  end
end
