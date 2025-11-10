export default {
  expo: {
    name: "AI Talk Coach",
    slug: "ai-talk-coach",
    version: "1.0.0",
    orientation: "portrait",
    icon: "./assets/logo.png",
    userInterfaceStyle: "light",
    newArchEnabled: true,
    splash: {
      image: "./assets/splash-icon.png",
      resizeMode: "contain",
      backgroundColor: "#ffffff"
    },
    ios: {
      bundleIdentifier: "com.aitalkcoach.app",
      buildNumber: "1",
      supportsTablet: false,
      infoPlist: {
        NSMicrophoneUsageDescription: "AI Talk Coach needs access to your microphone to record and analyze your speech patterns for providing personalized feedback.",
        NSCameraUsageDescription: "AI Talk Coach may use the camera for future video recording features to analyze visual communication.",
        NSPhotoLibraryUsageDescription: "AI Talk Coach needs access to save recorded sessions for your review."
      },
      config: {
        usesNonExemptEncryption: false
      }
    },
    android: {
      package: "com.aitalkcoach.app",
      versionCode: 1,
      adaptiveIcon: {
        foregroundImage: "./assets/adaptive-icon.png",
        backgroundColor: "#ffffff"
      },
      edgeToEdgeEnabled: true,
      permissions: [
        "RECORD_AUDIO"
      ]
    },
    web: {
      favicon: "./assets/favicon.png"
    },
    extra: {
      // Environment-specific configuration
      apiUrl: process.env.API_URL || "http://localhost:3000",
      environment: process.env.ENVIRONMENT || "development",
      // EAS Build environment variables
      eas: {
        projectId: process.env.EAS_PROJECT_ID || "19c933d6-2415-4f88-ac16-b923ab1894b2"
      }
    },
    // Production-specific settings
    ...(process.env.ENVIRONMENT === "production" && {
      ios: {
        bundleIdentifier: "com.aitalkcoach.app",
        buildNumber: process.env.IOS_BUILD_NUMBER || "1",
        supportsTablet: false,
        infoPlist: {
          NSMicrophoneUsageDescription: "AI Talk Coach needs access to your microphone to record and analyze your speech patterns for providing personalized feedback.",
          NSCameraUsageDescription: "AI Talk Coach may use the camera for future video recording features to analyze visual communication.",
          NSPhotoLibraryUsageDescription: "AI Talk Coach needs access to save recorded sessions for your review.",
          ITSAppUsesNonExemptEncryption: false
        },
        config: {
          usesNonExemptEncryption: false
        }
      },
      android: {
        package: "com.aitalkcoach.app",
        versionCode: parseInt(process.env.ANDROID_VERSION_CODE || "1"),
        adaptiveIcon: {
          foregroundImage: "./assets/adaptive-icon.png",
          backgroundColor: "#ffffff"
        },
        edgeToEdgeEnabled: true,
        permissions: [
          "RECORD_AUDIO"
        ]
      }
    })
  }
};