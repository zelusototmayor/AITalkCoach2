Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # =============================================================================
  # MARKETING SITE (aitalkcoach.com - no subdomain)
  # =============================================================================
  constraints subdomain: [ "", "www" ] do
    # Root route - landing page
    root "landing#index"

    # Pricing page
    get "pricing", to: "pricing#index"

    # Practice route for trial mode (public demo)
    get "practice", to: "sessions#index"

    # Session creation route for trial mode
    resources :sessions, only: [ :create ]

    # Trial session routes (public demo)
    resources :trial_sessions, only: [ :show ], param: :token, path: "trial" do
      member do
        get :analysis, action: :show
      end
    end

    # Trial session API routes
    namespace :api do
      resources :trial_sessions, only: [], param: :token do
        member do
          get :status
        end
      end
    end
  end

  # =============================================================================
  # APPLICATION (app.aitalkcoach.com)
  # =============================================================================
  constraints subdomain: "app" do
    # Redirect root on app subdomain to practice
    root "sessions#index", as: :app_root

    # Authentication routes
    namespace :auth do
      resources :registrations, only: [ :new, :create ], path: "signup"
      resources :sessions, only: [ :new, :create, :destroy ], path: "login"
      resources :password_resets, only: [ :new, :create, :edit, :update ], path: "password", param: :token
    end

    # Onboarding flow
    namespace :onboarding do
      get :welcome
      get :profile
      post :profile
      get :demographics
      post :demographics
      get :test
      post :test
      get :waiting
      get :report
      get :pricing
      post :pricing
      get :complete
      post :complete
    end

    # Convenient aliases
    get "/login", to: "auth/sessions#new"
    post "/login", to: "auth/sessions#create"
    delete "/logout", to: "auth/sessions#destroy", as: :logout
    get "/signup", to: "auth/registrations#new"
    post "/signup", to: "auth/registrations#create"

    # Practice route - the main app interface
    get "practice", to: "sessions#index"

    # Progress route - view user's improvement progress
    get "progress", to: "sessions#progress"

    # Core application routes
    resources :sessions, except: [ :edit, :update, :new ] do
      collection do
        get :history
      end
      member do
        delete :destroy
      end
    end

    resources :prompts, only: [ :index ]

    # Privacy settings
    resource :privacy_settings, only: [ :show, :update ]

    # Settings
    get "/settings", to: "settings#show"
    patch "/settings", to: "settings#update"

    # Feedback
    post "/feedback", to: "feedback#create"

    # Subscription routes
    resource :subscription, only: [ :create, :show ], controller: "subscription" do
      collection do
        get :success, action: :success
        post :manage, action: :manage
      end
    end

    # Webhooks
    post "/webhooks/stripe", to: "webhooks#stripe"

    # API routes
    namespace :api do
      resources :sessions, only: [] do
        collection do
          get :count
        end
        member do
          get :timeline
          get :export
          get :insights
          get :status
          post :reprocess_ai
        end
      end

      # Trial sessions API (for onboarding)
      resources :trial_sessions, only: [] do
        member do
          get :status
        end
      end
    end

    # Admin routes
    namespace :admin do
      get "health", to: "health#show"
      get "health/detailed", to: "health#detailed"
    end
  end
end
