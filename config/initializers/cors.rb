# CORS configuration for mobile app API access
# Allows React Native/Expo mobile app to make cross-origin requests

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # In development, allow all origins for easier testing
    # In production, restrict to your specific mobile app domains
    origins Rails.env.development? ? "*" : [
      "capacitor://localhost", # Capacitor apps
      "http://localhost",      # Expo Go on localhost
      /^exp:\/\//             # Expo development URLs (exp://192.168.x.x)
    ]

    # Allow mobile app to access session-related endpoints
    resource "/sessions*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
      credentials: false,
      expose: [ "Authorization" ] # Allow Authorization header in responses

    # Allow mobile app to access API endpoints
    resource "/api/*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
      credentials: false,
      expose: [ "Authorization" ] # Allow Authorization header in responses

    # Allow mobile app to access weekly focus endpoints
    resource "/weekly_focuses/*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
      credentials: false

    # Allow mobile app to access coach recommendations
    resource "/coach*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
      credentials: false

    # Allow mobile app to access progress data
    resource "/progress*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
      credentials: false

    # Allow mobile app to access practice session list
    resource "/practice*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
      credentials: false
  end
end
