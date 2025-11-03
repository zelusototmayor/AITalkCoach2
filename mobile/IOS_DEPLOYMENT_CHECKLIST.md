# iOS App Store Deployment Checklist for AI Talk Coach

## ✅ Already Completed

### Configuration Files
- [x] **app.json** - Updated with iOS configuration
  - Bundle ID: `com.aitalkcoach.app`
  - Build number: "1"
  - Privacy descriptions for microphone, camera, photo library

- [x] **app.config.js** - Created for dynamic configuration
  - Environment-based API URLs
  - Build-time variables support

- [x] **eas.json** - Build profiles configured
  - Development, preview, and production profiles
  - Resource classes and distribution settings

### Native Project
- [x] **iOS native project generated** (`npx expo prebuild`)
  - iOS directory created
  - Xcode project files generated
  - CocoaPods installed and configured

### Tools
- [x] **EAS CLI installed** (v16.26.0)
- [x] **CocoaPods installed** (v1.16.2)

## 🔄 Manual Steps Required

### 1. EAS Authentication (Required First)
```bash
cd /Users/zelu/ai_talk_coach/mobile

# Option A: Run the automated script
./setup-ios-credentials.sh

# Option B: Run commands manually
eas login                   # Login to your Expo account
eas build:configure         # Link project to EAS
eas credentials -p ios      # Generate certificates
```

**When logging in:**
- Use your Expo account credentials
- If you don't have an account, create one at https://expo.dev

### 2. Apple Developer Setup
- [ ] Apple Developer Account ($99/year) - https://developer.apple.com
- [ ] Accept all agreements in Apple Developer portal
- [ ] Create App ID for `com.aitalkcoach.app`
- [ ] Configure app capabilities if needed (Push Notifications, etc.)

### 3. Generate Credentials
When running `eas credentials -p ios`:
- [ ] Choose "Let EAS handle this for you" (recommended)
- [ ] Provide Apple Developer credentials when prompted
- [ ] Allow Expo to save credentials on their servers

## 📱 Building & Testing

### Development Build (for testing)
```bash
# Build for iOS Simulator
eas build -p ios --profile development --simulator

# Build for physical device
eas build -p ios --profile development
```

### Production Build (for App Store)
```bash
eas build -p ios --profile production
```

## 🚀 Submission Process

### 1. Build for Production
```bash
eas build -p ios --profile production
```

### 2. Submit to TestFlight
```bash
eas submit -p ios
```

### 3. App Store Connect Setup
- [ ] Add app metadata (description, keywords, categories)
- [ ] Upload screenshots for all required device sizes:
  - 6.7" (iPhone 15 Pro Max)
  - 6.5" (iPhone 14 Plus)
  - 5.5" (iPhone 8 Plus)
  - 12.9" iPad Pro (if supporting iPad)
- [ ] Set pricing and availability
- [ ] Add privacy policy URL
- [ ] Add support URL
- [ ] Configure age rating

### 4. Submit for Review
- [ ] Complete all required fields in App Store Connect
- [ ] Submit for App Store review
- [ ] Monitor review status
- [ ] Respond to any review feedback

## 📋 Pre-Submission Checklist

### App Functionality
- [ ] Test recording functionality
- [ ] Test all onboarding screens
- [ ] Verify API endpoints work in production
- [ ] Test payment/subscription flow
- [ ] Check error handling

### Legal & Compliance
- [ ] Privacy Policy URL active
- [ ] Terms of Service URL active
- [ ] GDPR compliance (if applicable)
- [ ] Export compliance (encryption)

### Assets & Content
- [ ] App icon (1024x1024) meets guidelines
- [ ] Screenshots are accurate and up-to-date
- [ ] App description is compelling
- [ ] Keywords are optimized
- [ ] Version notes prepared

## 🔗 Important URLs

- **Expo Dashboard**: https://expo.dev
- **Apple Developer**: https://developer.apple.com
- **App Store Connect**: https://appstoreconnect.apple.com
- **EAS Build Status**: https://expo.dev/accounts/[your-username]/projects/ai-talk-coach/builds

## 📝 Notes

### Current Configuration
- **Bundle ID**: `com.aitalkcoach.app`
- **App Name**: AI Talk Coach
- **Version**: 1.0.0
- **Build Number**: 1

### Environment URLs (update as needed)
- **Development**: http://localhost:3000
- **Staging**: https://staging.aitalkcoach.com
- **Production**: https://api.aitalkcoach.com

### Files to Update Before Production
1. Update API URLs in `eas.json`
2. Update Apple credentials in `eas.json` submit section
3. Increment version/build numbers as needed

## 🆘 Troubleshooting

### Common Issues

**"No iOS devices available in Simulator.app"**
- Open Xcode → Window → Devices and Simulators
- Download iOS simulators

**"Command failed: pod install"**
- Run `cd ios && pod install`
- If fails, try `pod repo update && pod install`

**"EAS Build failed"**
- Check build logs at https://expo.dev
- Verify all credentials are correct
- Ensure bundle ID matches Apple Developer portal

**"App Store submission rejected"**
- Review rejection reasons carefully
- Common issues: missing privacy descriptions, broken features, inappropriate content
- Fix issues and resubmit

## 🎉 Success Indicators

When everything is working correctly:
- ✅ EAS builds complete successfully
- ✅ App installs and runs on test devices
- ✅ TestFlight build available to testers
- ✅ App Store review approved
- ✅ App live on App Store!