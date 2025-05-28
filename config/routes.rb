Rails.application.routes.draw do
  devise_for :users, skip: [:registrations, :passwords, :confirmations],
                     controllers: { omniauth_callbacks: 'users/omniauth_callbacks' }

  devise_scope :user do
    delete 'users/sign_out', to: 'devise/sessions#destroy', as: :destroy_user_session
  end

  # Keep existing sign_in and sign_out routes if needed, or customize further.
  # For example, if you want to customize the sign_in path:
  # devise_scope :user do
  #   get 'login', to: 'devise/sessions#new', as: :new_user_session
  #   post 'login', to: 'devise/sessions#create', as: :user_session
  #   delete 'logout', to: 'devise/sessions#destroy', as: :destroy_user_session
  # end

  root "home#index"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
