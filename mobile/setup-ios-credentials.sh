#!/bin/bash

# iOS App Store Deployment - Credentials Setup Script
# This script will guide you through setting up Apple certificates and provisioning profiles

echo "================================================"
echo "AI Talk Coach - iOS Credentials Setup"
echo "================================================"
echo ""

# Step 1: Check if logged in to EAS
echo "Step 1: Checking EAS login status..."
if eas whoami 2>/dev/null; then
    echo "✅ Already logged in to EAS"
else
    echo "❌ Not logged in to EAS"
    echo ""
    echo "Please log in to your Expo account:"
    echo "Running: eas login"
    eas login

    if [ $? -ne 0 ]; then
        echo "❌ Failed to log in to EAS. Please try again."
        exit 1
    fi
    echo "✅ Successfully logged in to EAS"
fi

echo ""
echo "Step 2: Configuring EAS Build..."
echo "Running: eas build:configure"
eas build:configure

if [ $? -ne 0 ]; then
    echo "❌ Failed to configure EAS Build."
    echo "Note: If you see an error about project ID, you may need to create a project on expo.dev first"
    exit 1
fi

echo ""
echo "Step 3: Setting up iOS credentials..."
echo "This will generate:"
echo "  - Apple Distribution Certificate"
echo "  - Provisioning Profile"
echo ""
echo "When prompted:"
echo "  ✓ Choose 'Let EAS handle this for you' (recommended)"
echo "  ✓ Login with your Apple Developer credentials"
echo "  ✓ Allow Expo to save credentials"
echo ""
echo "Running: eas credentials -p ios"
eas credentials -p ios

if [ $? -ne 0 ]; then
    echo "❌ Failed to set up iOS credentials."
    echo "Make sure you have:"
    echo "  1. An active Apple Developer account ($99/year)"
    echo "  2. Accepted all agreements at developer.apple.com"
    echo "  3. Created an App ID for com.aitalkcoach.app"
    exit 1
fi

echo ""
echo "================================================"
echo "✅ iOS Credentials Setup Complete!"
echo "================================================"
echo ""
echo "Next steps:"
echo "1. Create a development build: eas build -p ios --profile development"
echo "2. Create a production build: eas build -p ios --profile production"
echo "3. Submit to TestFlight: eas submit -p ios"
echo ""
echo "Your app configuration:"
echo "  Bundle ID: com.aitalkcoach.app"
echo "  App Name: AI Talk Coach"
echo ""