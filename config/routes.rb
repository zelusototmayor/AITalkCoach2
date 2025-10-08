Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Root route - landing page
  root "landing#index"

  # Authentication routes
  namespace :auth do
    resources :registrations, only: [:new, :create], path: 'signup'
    resources :sessions, only: [:new, :create, :destroy], path: 'login'
  end

  # Convenient aliases
  get '/login', to: 'auth/sessions#new'
  post '/login', to: 'auth/sessions#create'
  delete '/logout', to: 'auth/sessions#destroy'
  get '/logout', to: 'auth/sessions#destroy'  # Fallback for direct GET requests
  get '/simple_logout', to: 'auth/sessions#destroy'  # Debug route
  get '/signup', to: 'auth/registrations#new'
  post '/signup', to: 'auth/registrations#create'

  # Practice route - the main app interface
  get "practice", to: "sessions#index"

  # Progress route - view user's improvement progress
  get "progress", to: "sessions#progress"

  # Core application routes
  resources :sessions, except: [:edit, :update, :new] do
    collection do
      get :history
    end
    member do
      delete :destroy
    end
  end
  
  resources :prompts, only: [:index]
  
  # Privacy settings
  resource :privacy_settings, only: [:show, :update]

  # Feedback
  post '/feedback', to: 'feedback#create'

  # Trial session routes (token-based, no authentication)
  resources :trial_sessions, only: [:show], param: :token, path: 'trial' do
    member do
      get :analysis, action: :show
    end
  end

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

    # Trial session API routes
    resources :trial_sessions, only: [], param: :token do
      member do
        get :status
      end
    end
  end
  
  # Admin routes
  namespace :admin do
    get 'health', to: 'health#show'
    get 'health/detailed', to: 'health#detailed'
  end
end
