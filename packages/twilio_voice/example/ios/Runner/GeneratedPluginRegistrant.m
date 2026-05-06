//
//  Generated file. Do not edit.
//

// clang-format off

#import "GeneratedPluginRegistrant.h"

#if __has_include(<cloud_functions/FirebaseFunctionsPlugin.h>)
#import <cloud_functions/FirebaseFunctionsPlugin.h>
#else
@import cloud_functions;
#endif

#if __has_include(<firebase_analytics/FirebaseAnalyticsPlugin.h>)
#import <firebase_analytics/FirebaseAnalyticsPlugin.h>
#else
@import firebase_analytics;
#endif

#if __has_include(<firebase_auth/FLTFirebaseAuthPlugin.h>)
#import <firebase_auth/FLTFirebaseAuthPlugin.h>
#else
@import firebase_auth;
#endif

#if __has_include(<firebase_core/FLTFirebaseCorePlugin.h>)
#import <firebase_core/FLTFirebaseCorePlugin.h>
#else
@import firebase_core;
#endif

#if __has_include(<firebase_messaging/FLTFirebaseMessagingPlugin.h>)
#import <firebase_messaging/FLTFirebaseMessagingPlugin.h>
#else
@import firebase_messaging;
#endif

#if __has_include(<twilio_voice/TwilioVoicePlugin.h>)
#import <twilio_voice/TwilioVoicePlugin.h>
#else
@import twilio_voice;
#endif

@implementation GeneratedPluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [FirebaseFunctionsPlugin registerWithRegistrar:[registry registrarForPlugin:@"FirebaseFunctionsPlugin"]];
  [FirebaseAnalyticsPlugin registerWithRegistrar:[registry registrarForPlugin:@"FirebaseAnalyticsPlugin"]];
  [FLTFirebaseAuthPlugin registerWithRegistrar:[registry registrarForPlugin:@"FLTFirebaseAuthPlugin"]];
  [FLTFirebaseCorePlugin registerWithRegistrar:[registry registrarForPlugin:@"FLTFirebaseCorePlugin"]];
  [FLTFirebaseMessagingPlugin registerWithRegistrar:[registry registrarForPlugin:@"FLTFirebaseMessagingPlugin"]];
  [TwilioVoicePlugin registerWithRegistrar:[registry registrarForPlugin:@"TwilioVoicePlugin"]];
}

@end
