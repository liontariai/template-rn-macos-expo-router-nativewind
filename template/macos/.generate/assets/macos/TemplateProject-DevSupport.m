#import <Foundation/Foundation.h>

NSNotificationName const TemplateProjectDidInitializeNotification =
    @"TemplateProjectDidInitializeNotification";

NSNotificationName const TemplateProjectWillInitializeReactNativeNotification =
    @"TemplateProjectWillInitializeReactNativeNotification";
NSNotificationName const TemplateProjectDidInitializeReactNativeNotification =
    @"TemplateProjectDidInitializeReactNativeNotification";
NSNotificationName const TemplateProjectDidRegisterAppsNotification =
    @"TemplateProjectDidRegisterAppsNotification";

NSNotificationName const TemplateProjectSceneDidOpenURLNotification =
    @"TemplateProjectSceneDidOpenURLNotification";

// https://github.com/facebook/react-native/blob/v0.73.4/packages/react-native/ReactCommon/react/runtime/platform/ios/ReactCommon/RCTInstance.mm#L448
NSNotificationName const ReactInstanceDidLoadBundle = @"RCTInstanceDidLoadBundle";
