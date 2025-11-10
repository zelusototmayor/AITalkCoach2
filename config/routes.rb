Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # =============================================================================
  # MOBILE API ROUTES (works with IP addresses, no subdomain required)
  # =============================================================================
  # API namespace for mobile app
  namespace :api do
    namespace :v1 do
      # Authentication
      post 'auth/login', to: 'auth#login'
      post 'auth/signup', to: 'auth#signup'
      post 'auth/refresh', to: 'auth#refresh'
      get 'auth/me', to: 'auth#me'
      post 'auth/logout', to: 'auth#logout'
      post 'auth/forgot_password', to: 'auth#forgot_password'
      post 'auth/reset_password', to: 'auth#reset_password'
      post 'auth/complete_onboarding', to: 'auth#complete_onboarding'
      patch 'auth/update_profile', to: 'auth#update_profile'
      patch 'auth/update_language', to: 'auth#update_language'
      delete 'auth/account', to: 'auth#delete_account'

      # Sessions
      resources :sessions, only: [:index, :show, :create, :destroy] do
        member do
          get 'status'
          post 'retake'
          post 'continue_anyway'
        end
      end

      # Progress
      get 'progress', to: 'progress#index'

      # Coach
      get 'coach', to: 'coach#index'

      # Prompts
      get 'prompts', to: 'prompts#index'
      get 'prompts/daily', to: 'sessions#daily_prompt'
      get 'prompts/shuffle', to: 'sessions#shuffle_prompt'
      post 'prompts/complete', to: 'sessions#complete_prompt'

      # Subscriptions (Apple IAP via RevenueCat)
      get 'subscriptions/status', to: 'subscriptions#status'
      post 'subscriptions/sync', to: 'subscriptions#sync'
      post 'subscriptions/restore', to: 'subscriptions#restore'
    end
  end

  # RevenueCat webhook (outside subdomain constraints, accepts any request)
  post "/webhooks/revenuecat", to: "webhooks#revenuecat"

  # Legacy mobile API routes (for backward compatibility during transition)
  # These routes must come BEFORE subdomain constraints to allow mobile app
  # access via IP address (e.g., http://192.168.100.38:3002)
  # They only match JSON requests, so web browser requests fall through to
  # subdomain-based routes below.
  scope constraints: ->(req) { req.format == :json } do
    # Coach recommendations endpoint
    get "coach", to: "sessions#coach"

    # Session resources for mobile app
    resources :sessions, only: [ :show, :create ] do
      member do
        get :status
      end
    end

    # Trial sessions for mobile app (onboarding)
    namespace :api do
      resources :trial_sessions, only: [ :create, :show ], param: :token do
        member do
          get :status
        end
      end
    end
  end

  # =============================================================================
  # MARKETING SITE (aitalkcoach.com - no subdomain)
  # =============================================================================
  constraints subdomain: [ "", "www" ] do
    # Root route - landing page
    root "landing#index"

    # Blog routes
    resources :blog_posts, only: [:index, :show], path: "blog", param: :slug

    # Legal pages
    get "privacy", to: "legal#privacy", as: :privacy_policy
    get "terms", to: "legal#terms", as: :terms_of_service
    get "contact", to: "legal#contact", as: :contact

    # Pricing page
    get "pricing", to: "pricing#index"

    # Partners program
    get "partners", to: "partners#index"
    post "partners", to: "partners#create"

    # Practice route for trial mode (public demo)
    get "practice", to: "sessions#index"

    # Session creation route for trial mode
    resources :sessions, only: [ :create, :show ] do
      member do
        get :status
      end
    end

    # Coach recommendations (for mobile app)
    get "coach", to: "sessions#coach"

    # Trial session routes (public demo)
    resources :trial_sessions, only: [ :show ], param: :token, path: "trial" do
      member do
        get :analysis, action: :show
      end
    end

    # Trial session API routes
    namespace :api do
      resources :trial_sessions, only: [ :show ], param: :token do
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
      get :splash
      get :welcome
      get :profile
      post :profile
      get :motivation
      get :demographics
      post :demographics
      get :test
      post :test
      get :waiting
      get :report
      get :cinematic
      get :pricing
      post :pricing
      get :complete
      post :complete
    end

    # Convenient aliases
    get "/login", to: "auth/sessions#new"
    post "/login", to: "auth/sessions#create"
    match "/logout", to: "auth/sessions#destroy", via: [:get, :delete], as: :logout
    get "/signup", to: "auth/registrations#new"
    post "/signup", to: "auth/registrations#create"

    # Practice route - the main app interface
    get "practice", to: "sessions#index"

    # Progress route - view user's improvement progress
    get "progress", to: "sessions#progress"

    # Coach route - personalized coaching and daily plan
    get "coach", to: "sessions#coach"

    # Core application routes
    resources :sessions, except: [ :edit, :update, :new ] do
      collection do
        get :history
      end
      member do
        get :status
        delete :destroy
      end
    end

    resources :prompts, only: [ :index ]

    # Prompt API endpoints for web app
    get "prompts/daily", to: "sessions#daily_prompt"
    get "prompts/shuffle", to: "sessions#shuffle_prompt"
    post "prompts/complete", to: "sessions#complete_prompt"

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

      # Blog CMS
      resources :blog_posts
    end
  end
end
