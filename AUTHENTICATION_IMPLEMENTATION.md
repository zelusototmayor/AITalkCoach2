# Unified Authentication System Implementation

## Overview
This document describes the unified authentication system implemented for both the web and mobile applications of AI Talk Coach. The system uses JWT-based authentication for mobile apps while maintaining backward compatibility with session-based authentication for the web application.

## Implementation Summary

### Backend (Rails API)

#### 1. JWT Token Management
- **Location**: `app/lib/json_web_token.rb`
- **Purpose**: Handles JWT encoding/decoding with Rails secret key
- **Features**:
  - 24-hour default token expiration
  - Refresh tokens with 30-day expiration
  - HS256 algorithm for signing

#### 2. API Controllers

##### Base Controller
- **Location**: `app/controllers/api/v1/base_controller.rb`
- **Features**:
  - JWT authentication for all API requests
  - Error handling for expired/invalid tokens
  - Automatic user context from token

##### Authentication Controller
- **Location**: `app/controllers/api/v1/auth_controller.rb`
- **Endpoints**:
  - `POST /api/v1/auth/login` - User login
  - `POST /api/v1/auth/signup` - User registration
  - `POST /api/v1/auth/refresh` - Refresh access token
  - `GET /api/v1/auth/me` - Get current user
  - `POST /api/v1/auth/logout` - Logout (client-side)
  - `POST /api/v1/auth/forgot_password` - Request password reset
  - `POST /api/v1/auth/reset_password` - Reset password

##### Session Management
- **Location**: `app/controllers/api/v1/sessions_controller.rb`
- **Features**: Full CRUD operations for practice sessions with authentication

##### Progress Tracking
- **Location**: `app/controllers/api/v1/progress_controller.rb`
- **Features**: Progress metrics and achievements with authentication

##### Coach Recommendations
- **Location**: `app/controllers/api/v1/coach_controller.rb`
- **Features**: Personalized coaching recommendations

#### 3. CORS Configuration
- **Location**: `config/initializers/cors.rb`
- **Features**:
  - Allows mobile app access from any origin in development
  - Exposes Authorization header for JWT tokens
  - Supports Expo and Capacitor apps

### Mobile App (React Native)

#### 1. Authentication Context
- **Location**: `mobile/context/AuthContext.js`
- **Features**:
  - Secure token storage using expo-secure-store
  - Automatic token refresh
  - User state management
  - Session persistence

#### 2. Authentication Service
- **Location**: `mobile/services/authService.js`
- **Features**:
  - All authentication API calls
  - Token refresh logic
  - Error handling

#### 3. API Service Updates
- **Location**: `mobile/services/api.js`
- **Features**:
  - Automatic token injection in headers
  - Updated all endpoints to use authentication
  - Removed hardcoded user IDs

#### 4. UI Updates

##### Login Screen
- **Location**: `mobile/screens/auth/LoginScreen.js`
- **Features**:
  - Real authentication API integration
  - Loading states
  - Error handling and display
  - Navigation to authenticated app

##### Signup Screen
- **Location**: `mobile/screens/auth/SignUpScreen.js`
- **Features**:
  - User registration
  - Validation
  - Error handling
  - Auto-login after signup

##### Navigation
- **Location**: `mobile/navigation/MainNavigator.js`
- **Features**:
  - Authentication-based navigation
  - Separate stacks for auth and app
  - Bottom tab navigation for authenticated users

## Security Features

1. **Token Security**:
   - Tokens stored in Expo SecureStore (encrypted storage)
   - Separate access and refresh tokens
   - Automatic token refresh before expiration

2. **Password Security**:
   - bcrypt for password hashing
   - Password reset tokens with expiration
   - Minimum password requirements

3. **API Security**:
   - All API endpoints require authentication
   - Token validation on every request
   - CORS protection

## Migration Notes

### For Existing Users
- Web users can continue using session-based auth
- Mobile users need to login with their existing credentials
- All user data is preserved

### For Developers
1. Update local `.env` with JWT secret if needed
2. Run `bundle install` to get JWT gem
3. Run `npm install` in mobile directory for new packages
4. Update API_BASE_URL in mobile app for your environment

## Testing the Implementation

### Backend Testing
```bash
# Test login
curl -X POST http://localhost:3002/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password"}'

# Test authenticated request
curl -X GET http://localhost:3002/api/v1/auth/me \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

### Mobile Testing
1. Start Rails server: `rails s -p 3002`
2. Update IP address in `mobile/services/api.js`
3. Start Expo: `cd mobile && npm start`
4. Test login/signup flow in the app

## Future Enhancements

1. **Token Blacklisting**: Implement server-side token invalidation
2. **Biometric Authentication**: Add Face ID/Touch ID support
3. **OAuth Integration**: Add social login options
4. **2FA Support**: Two-factor authentication
5. **Session Management**: Allow users to see/manage active sessions

## Troubleshooting

### Common Issues

1. **CORS Errors**: Ensure Rails server is running and CORS is configured
2. **Token Expired**: App should auto-refresh, but user can re-login
3. **Network Errors**: Check IP address and network connectivity
4. **Storage Errors**: Ensure app has permissions for secure storage

### Debug Tips
- Check Rails logs for API errors
- Use React Native debugger for mobile app
- Verify tokens using JWT.io debugger
- Check network requests in browser/Expo dev tools