#import <AppSupport/CPDistributedMessagingCenter.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <UIKit/UIKit.h>

#import <HBLog.h>
#import <libSandy.h>
#import <libroot.h>

#import "NoRedirectRecord.h"

@interface BSProcessHandle : NSObject
@property(getter=isValid, nonatomic, assign, readonly) BOOL valid;
@property(nonatomic, assign, readonly) int pid;
@property(nonatomic, copy, readonly) NSString *bundleIdentifier;
@property(nonatomic, copy, readonly) NSString *name;
@end

@interface SBApplicationProcessState : NSObject
@property(nonatomic, assign, readonly) int pid;
@property(getter=isRunning, nonatomic, assign, readonly) BOOL running;
@property(getter=isForeground, nonatomic, assign, readonly) BOOL foreground;
@end

@interface SBApplication : NSObject
@property(nonatomic, copy, readonly) NSString *bundleIdentifier;
@property(nonatomic, copy, readonly) NSString *displayName;
@property(nonatomic, strong, readonly) SBApplicationProcessState *processState;
@end

@interface SBApplicationSceneEntity : NSObject
@property(nonatomic, strong, readonly) SBApplication *application;
@property(nonatomic, copy, readonly) NSSet *actions;
@end

@interface SBLayoutElement : NSObject
@property(nonatomic, copy, readonly) NSString *uniqueIdentifier;
@end

@interface SBLayoutState : NSObject
@property(nonatomic, readonly) NSSet<SBLayoutElement *> *elements;
- (SBLayoutElement *)elementWithRole:(long long)arg1;
@end

@interface SBWorkspaceApplicationSceneTransitionContext : NSObject
@property(nonatomic, copy, readonly) NSSet<SBApplicationSceneEntity *> *applicationSceneEntities;
@property(nonatomic, copy, readonly) NSSet<SBApplicationSceneEntity *> *previousApplicationSceneEntities;
@property(nonatomic, strong, readonly) SBLayoutState *previousLayoutState;
@property(nonatomic, strong, readonly) SBLayoutState *layoutState;
- (void)setBackground:(BOOL)arg1;
@end

@interface SBWorkspaceTransitionRequest : NSObject
@property(nonatomic, copy, readonly) NSSet<SBApplicationSceneEntity *> *toApplicationSceneEntities;
@property(nonatomic, copy, readonly) NSSet<SBApplicationSceneEntity *> *fromApplicationSceneEntities;
@property(nonatomic, copy, readonly) NSString *eventLabel;
@property(nonatomic, strong, readonly) BSProcessHandle *originatingProcess;
@property(nonatomic, strong, readonly) SBWorkspaceApplicationSceneTransitionContext *applicationContext;
- (void)declineWithReason:(id)arg1;
@end

@interface SBApplicationInfo : NSObject
@property(nonatomic, copy, readonly) NSString *bundleIdentifier;
@end

@interface UIViewController (NoRedirect)
- (NSString *)_hostApplicationBundleIdentifier;
@end

@interface _SFBrowserContentViewController : UIViewController
- (void)_dismiss;
@end

@interface RBSProcessBundle : NSObject
@property(readonly, copy, nonatomic) NSString *identifier;
- (id)bundleInfoValueForKey:(NSString *)arg1;
@end

@interface RBSProcessHandle : NSObject
@property(readonly, nonatomic) RBSProcessBundle *bundle;
@end

@interface RBProcess : NSObject
@property(nonatomic, copy, readonly) RBSProcessHandle *handle;
@end

@interface RBSProcessIdentity : NSObject
@property(readonly, copy, nonatomic) NSString *xpcServiceIdentifier;
+ (instancetype)identityForXPCServiceIdentifier:(NSString *)arg1;
@end

@interface RBSLaunchContext : NSObject
@property(nonatomic, retain) RBProcess *hostProcess;
@property(copy, nonatomic) RBSProcessIdentity *identity;
@end

@interface RBSLaunchRequest : NSObject
@property(nonatomic, readonly) RBSLaunchContext *context;
@end

static BOOL gEnabled = YES;
static BOOL gBannerEnabled = YES;
static BOOL gRecordingEnabled = NO;
static BOOL gIsSafariViewService = NO;
static BOOL gIsRunningBoardDaemon = NO;

static NSSet<NSString *> *gForbiddenLaunchSources = nil;
static NSSet<NSString *> *gForbiddenLaunchDestinations = nil;

static NSSet<NSString *> *gForbiddenLaunchSourcesForAppStore = nil;
static NSSet<NSString *> *gForbiddenLaunchSourcesForSafariServices = nil;

static NSSet<NSString *> *gForbiddenHotspotHandlers = nil;
static NSSet<NSString *> *gForbiddenPrewarmDestinations = nil;

static NSSet<NSString *> *gUseLenientModeSources = nil;
static NSSet<NSString *> *gUseHandledSimulationSources = nil;

// %@->%@
static NSSet<NSString *> *gCustomAllowedMappings = nil;
static NSSet<NSString *> *gCustomForbiddenMappings = nil;

static NSMutableDictionary<NSString *, NSNumber *> *gLastTransitionStamps = nil;
static CPDistributedMessagingCenter *gMessagingCenter = nil;

static void ReloadPrefs(void) {
    static NSUserDefaults *prefs = nil;
    if (!prefs) {
        if (gIsSafariViewService || gIsRunningBoardDaemon) {
            prefs = [[NSUserDefaults alloc]
                initWithSuiteName:@"/var/mobile/Library/Preferences/com.82flex.noredirectprefs.plist"];
        } else {
            prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.82flex.noredirectprefs"];
        }
    }

    NSDictionary *settings = [prefs dictionaryRepresentation];

    gEnabled = settings[@"IsEnabled"] ? [settings[@"IsEnabled"] boolValue] : YES;
    gBannerEnabled = settings[@"IsBannerEnabled"] ? [settings[@"IsBannerEnabled"] boolValue] : YES;
    gRecordingEnabled = settings[@"IsRecordingEnabled"] ? [settings[@"IsRecordingEnabled"] boolValue] : NO;

    HBLogDebug(@"Enabled: %@, Banner Enabled: %@, Recording Enabled: %@", gEnabled ? @"YES" : @"NO",
               gBannerEnabled ? @"YES" : @"NO", gRecordingEnabled ? @"YES" : @"NO");

    NSMutableSet *forbiddenLaunchSources = [NSMutableSet set];
    for (NSString *key in settings) {
        if ([key hasPrefix:@"IsBlockedFromLaunchingOthers/"] && [settings[key] boolValue]) {
            NSString *appId = [key substringFromIndex:29];
            [forbiddenLaunchSources addObject:appId];
        }
    }
    gForbiddenLaunchSources = [forbiddenLaunchSources copy];
    HBLogDebug(@"Forbidden Launch Sources: %@", forbiddenLaunchSources);

    NSMutableSet *forbiddenLaunchDestinations = [NSMutableSet set];
    for (NSString *key in settings) {
        if ([key hasPrefix:@"IsBlockedFromBeingLaunched/"] && [settings[key] boolValue]) {
            NSString *appId = [key substringFromIndex:27];
            [forbiddenLaunchDestinations addObject:appId];
        }
    }
    gForbiddenLaunchDestinations = [forbiddenLaunchDestinations copy];
    HBLogDebug(@"Forbidden Launch Destinations: %@", forbiddenLaunchDestinations);

    NSMutableSet *forbiddenHotspotHandlers = [NSMutableSet set];
    for (NSString *key in settings) {
        if ([key hasPrefix:@"IsBlockedFromBeingLaunchedAsHotspotHelper/"] && [settings[key] boolValue]) {
            NSString *appId = [key substringFromIndex:42];
            [forbiddenHotspotHandlers addObject:appId];
        }
    }
    gForbiddenHotspotHandlers = [forbiddenHotspotHandlers copy];
    HBLogDebug(@"Forbidden Hotspot Handlers: %@", forbiddenHotspotHandlers);

    NSMutableSet *forbiddenPrewarmDestinations = [NSMutableSet set];
    for (NSString *key in settings) {
        if ([key hasPrefix:@"IsBlockedFromBeingPrewarmed/"] && [settings[key] boolValue]) {
            NSString *appId = [key substringFromIndex:28];
            [forbiddenPrewarmDestinations addObject:appId];
        }
    }
    gForbiddenPrewarmDestinations = [forbiddenPrewarmDestinations copy];
    HBLogDebug(@"Forbidden Prewarm Destinations: %@", forbiddenPrewarmDestinations);

    NSMutableSet *forbiddenLaunchSourcesForAppStore = [NSMutableSet set];
    for (NSString *key in settings) {
        if ([key hasPrefix:@"IsBlockedFromLaunchingAppStore/"] && [settings[key] boolValue]) {
            NSString *appId = [key substringFromIndex:31];
            [forbiddenLaunchSourcesForAppStore addObject:appId];
        }
    }
    gForbiddenLaunchSourcesForAppStore = [forbiddenLaunchSourcesForAppStore copy];
    HBLogDebug(@"Forbidden Launch Sources for App Store: %@", forbiddenLaunchSourcesForAppStore);

    NSMutableSet *forbiddenLaunchSourcesForSafariServices = [NSMutableSet set];
    for (NSString *key in settings) {
        if ([key hasPrefix:@"IsBlockedFromLaunchingSafari/"] && [settings[key] boolValue]) {
            NSString *appId = [key substringFromIndex:29];
            [forbiddenLaunchSourcesForSafariServices addObject:appId];
        }
    }
    gForbiddenLaunchSourcesForSafariServices = [forbiddenLaunchSourcesForSafariServices copy];
    HBLogDebug(@"Forbidden Launch Sources for Safari Services: %@", forbiddenLaunchSourcesForSafariServices);

    NSMutableSet *customAllowedMappings = [NSMutableSet set];
    for (NSString *key in settings) {
        if ([key hasPrefix:@"CustomBypassedApplications/"]) {
            NSString *srcId = [key substringFromIndex:27];
            NSArray *destIds = settings[key];
            if ([destIds isKindOfClass:[NSArray class]]) {
                for (NSString *destId in destIds) {
                    [customAllowedMappings addObject:[NSString stringWithFormat:@"%@->%@", destId, srcId]];
                }
            }
        }
    }
    gCustomAllowedMappings = [customAllowedMappings copy];
    HBLogDebug(@"Custom Allowed Mappings: %@", customAllowedMappings);

    NSMutableSet *customForbiddenMappings = [NSMutableSet set];
    for (NSString *key in settings) {
        if ([key hasPrefix:@"CustomBlockedApplications/"]) {
            NSString *srcId = [key substringFromIndex:26];
            NSArray *destIds = settings[key];
            if ([destIds isKindOfClass:[NSArray class]]) {
                for (NSString *destId in destIds) {
                    [customForbiddenMappings addObject:[NSString stringWithFormat:@"%@->%@", srcId, destId]];
                }
            }
        }
    }
    gCustomForbiddenMappings = [customForbiddenMappings copy];
    HBLogDebug(@"Custom Forbidden Mappings: %@", customForbiddenMappings);

    NSMutableSet *useLenientModeSources = [NSMutableSet set];
    for (NSString *key in settings) {
        if ([key hasPrefix:@"ShouldTeardownAutomatically/"] && [settings[key] boolValue]) {
            NSString *appId = [key substringFromIndex:28];
            [useLenientModeSources addObject:appId];
        }
    }
    gUseLenientModeSources = [useLenientModeSources copy];
    HBLogDebug(@"Use Lenient Mode Sources: %@", useLenientModeSources);

    NSMutableSet *useHandledSimulationSources = [NSMutableSet set];
    for (NSString *key in settings) {
        if ([key hasPrefix:@"ShouldSimulateSuccess/"] && [settings[key] boolValue]) {
            NSString *appId = [key substringFromIndex:22];
            [useHandledSimulationSources addObject:appId];
        }
    }
    gUseHandledSimulationSources = [useHandledSimulationSources copy];
    HBLogDebug(@"Use Handled Simulation Sources: %@", useHandledSimulationSources);
}

static BOOL ShouldDeclineRequest(NSString *srcId, NSString *destId) {
    if (!srcId || !destId) {
        return NO;
    }

    HBLogDebug(@"Checking if %@ should be allowed to launch %@", srcId, destId);

    if (!gEnabled) {
        HBLogDebug(@"> [ACCEPT] NoRedirect is disabled");
        return NO;
    }

    if ([srcId isEqualToString:destId]) {
        HBLogDebug(@"> [ACCEPT] Source and destination are the same: %@", srcId);
        return NO;
    }

    if ([gUseLenientModeSources containsObject:srcId]) {
        HBLogDebug(@"> [ACCEPT] %@ is in lenient mode", srcId);

        if (gLastTransitionStamps[srcId]) {
            CFTimeInterval lastTransitionStamp = [gLastTransitionStamps[srcId] doubleValue];
            CFTimeInterval nowStamp = CACurrentMediaTime();
            CFTimeInterval lastInterval = fabs(nowStamp - lastTransitionStamp);
            if (lastInterval > 10.0) {
                HBLogDebug(@">> [ACCEPT] Last transition was %.3f seconds ago", lastInterval);
                return NO;
            }
        }
    }

    NSString *mapping = [NSString stringWithFormat:@"%@->%@", srcId, destId];
    if ([gCustomAllowedMappings containsObject:mapping]) {
        HBLogDebug(@"> [ACCEPT] Custom mapping %@ is allowed", mapping);
        return NO;
    }

    if ([gForbiddenLaunchSources containsObject:srcId]) {
        HBLogDebug(@"> [REJECT] %@ is forbidden from launching others", srcId);
        return YES;
    }

    if ([srcId isEqualToString:@"com.apple.configd"] && [gForbiddenHotspotHandlers containsObject:destId]) {
        HBLogDebug(@"> [REJECT] %@ is forbidden from being launched as Hotspot Helper", destId);
        return YES;
    }

    if ([srcId isEqualToString:@"com.apple.dasd"] && [gForbiddenPrewarmDestinations containsObject:destId]) {
        HBLogDebug(@"> [REJECT] %@ is forbidden from being prewarmed", destId);
        return YES;
    }

    if ([gForbiddenLaunchDestinations containsObject:destId]) {
        HBLogDebug(@"> [REJECT] %@ is forbidden from being launched", destId);

        if ([srcId hasPrefix:@"com.apple."]) {
            BOOL isSafariViewService = [srcId isEqualToString:@"com.apple.mobilesafari"] ||
                                       [srcId isEqualToString:@"com.apple.SafariViewService"];
            if (!isSafariViewService) {
                HBLogDebug(@">> [ACCEPT] %@ is a system application except Safari View Service", srcId);
                return NO;
            }
        }

        return YES;
    }

    if (([destId isEqualToString:@"com.apple.AppStore"] ||
         [destId isEqualToString:@"com.apple.ios.StoreKitUIService"]) &&
        [gForbiddenLaunchSourcesForAppStore containsObject:srcId]) {
        HBLogDebug(@"> [REJECT] %@ is forbidden from launching App Store", srcId);
        return YES;
    }

    if (([destId isEqualToString:@"com.apple.mobilesafari"] ||
         [destId isEqualToString:@"com.apple.SafariViewService"]) &&
        [gForbiddenLaunchSourcesForSafariServices containsObject:srcId]) {
        HBLogDebug(@"> [REJECT] %@ is forbidden from launching Safari View Service", srcId);
        return YES;
    }

    if ([gCustomForbiddenMappings containsObject:mapping]) {
        HBLogDebug(@"> [REJECT] Custom mapping %@ is forbidden", mapping);
        return YES;
    }

    HBLogDebug(@"> [ACCEPT] Allowed");
    return NO;
}

static void RecordRequest(NSString *srcId, NSString *destId, BOOL declined) {
    if (!srcId || !destId) {
        return;
    }

    if (!gRecordingEnabled) {
        return;
    }

    if ([srcId isEqualToString:@"com.apple.springboard"]) {
        return;
    }

    if ([destId isEqualToString:@"com.apple.SafariViewService"]) {
        destId = @"com.apple.mobilesafari";
    } else if ([destId isEqualToString:@"com.apple.ios.StoreKitUIService"]) {
        destId = @"com.apple.AppStore";
    }

    [NoRedirectRecord insertRecord:declined source:srcId target:destId];
}

static NSBundle *NRUSupportBundle(void) {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      NSString *tweakBundlePath = [[NSBundle mainBundle] pathForResource:@"NoRedirectPrefs" ofType:@"bundle"];
      NSString *aliasBundlePath;
      aliasBundlePath = JBROOT_PATH_NSSTRING(@"/Library/PreferenceBundles/NoRedirectPrefs.bundle");
      bundle = [NSBundle bundleWithPath:tweakBundlePath ?: aliasBundlePath];
    });
    return bundle;
}

%group NoRedirectPrimary

%hook SBMainWorkspace

- (BOOL)_executeTransitionRequest:(id)arg1 options:(unsigned long long)arg2 validator:(id)arg3 {
    HBLogDebug(@"_executeTransitionRequest: %@, options: %llu, validator: %@", arg1, (unsigned long long)arg2, arg3);

    BOOL transitionFinished = %orig;
    if (!transitionFinished) {
        return NO;
    }

    if (!gEnabled) {
        return transitionFinished;
    }

    if (![arg1 isKindOfClass:%c(SBMainWorkspaceTransitionRequest)]) {
        return transitionFinished;
    }

    SBWorkspaceTransitionRequest *request = (SBWorkspaceTransitionRequest *)arg1;
    SBApplicationSceneEntity *toEntity = request.toApplicationSceneEntities.anyObject;
    NSString *toAppId = toEntity.application.bundleIdentifier;
    if (!toAppId) {
        return transitionFinished;
    }

    if (!gLastTransitionStamps) {
        gLastTransitionStamps = [NSMutableDictionary dictionary];
    }

    gLastTransitionStamps[toAppId] = @(CACurrentMediaTime());
    HBLogDebug(@"Recorded transition to %@ at %.3f", toAppId, [gLastTransitionStamps[toAppId] doubleValue]);
    return transitionFinished;
}

- (BOOL)_canExecuteTransitionRequest:(id)arg1 forExecution:(BOOL)arg2 {
    if (!gEnabled) {
        return %orig;
    }

    HBLogDebug(@"Checking if transition request can be executed: %@", arg1);

    if (![arg1 isKindOfClass:%c(SBMainWorkspaceTransitionRequest)]) {
        return %orig;
    }

    BOOL isFromBreadcrumb = NO;
    SBWorkspaceTransitionRequest *request = (SBWorkspaceTransitionRequest *)arg1;
    NSString *eventLabel = request.eventLabel;
    if (eventLabel) {
        HBLogDebug(@"Event Label: %@", eventLabel);

        isFromBreadcrumb = [eventLabel containsString:@"ActivateFromBreadcrumb"];
        BOOL isEligibleForDecline = isFromBreadcrumb || ([eventLabel containsString:@"OpenApplication"] && [eventLabel containsString:@"ForRequester"]);
        if (!isEligibleForDecline) {
            return %orig;
        }
    }

    NSString *fromAppId = nil;
    NSString *fromAppName = nil;
    NSString *fromProcessName = nil;

    SBApplicationSceneEntity *fromEntity = request.fromApplicationSceneEntities.anyObject;
    if (fromEntity) {
        id fromAction = fromEntity.actions.anyObject;
        if (fromAction) {
            HBLogDebug(@"From Action: %@", fromAction);

            BOOL isEligibleForDecline = [fromAction isKindOfClass:%c(UIOpenURLAction)];
            if (!isEligibleForDecline) {
                return %orig;
            }
        }

        fromAppId = fromEntity.application.bundleIdentifier;
        fromAppName = fromEntity.application.displayName;
    } else {
        fromProcessName = request.originatingProcess.name;
        if (isFromBreadcrumb || [fromProcessName isEqualToString:@"lsd"]) {
            SBLayoutElement *fromElement = [request.applicationContext.previousLayoutState elementWithRole:1];
            fromAppId = fromElement.uniqueIdentifier;

            if ([fromAppId hasPrefix:@"sceneID:"]) {
                fromAppId = [fromAppId substringFromIndex:8];
            }

            if ([fromAppId hasSuffix:@"-default"]) {
                fromAppId = [fromAppId substringToIndex:fromAppId.length - 8];
            } else if (fromAppId.length > 37) {
                fromAppId = [fromAppId substringToIndex:fromAppId.length - 37];
            }
        }
    }

    fromAppId = fromAppId ?: request.originatingProcess.bundleIdentifier;
    SBApplicationSceneEntity *toEntity = request.toApplicationSceneEntities.anyObject;

    NSString *toAppId = toEntity.application.bundleIdentifier;
    if (fromAppId && toAppId && [fromAppId isEqualToString:toAppId]) {
        return %orig;
    }

    NSString *toAppName = toEntity.application.displayName;
    if (!fromAppName && fromAppId) {
        LSApplicationProxy *fromAppProxy = [LSApplicationProxy applicationProxyForIdentifier:fromAppId];
        fromAppName = fromAppProxy.localizedName;
    }
    if (!toAppName && toAppId) {
        LSApplicationProxy *toAppProxy = [LSApplicationProxy applicationProxyForIdentifier:toAppId];
        toAppName = toAppProxy.localizedName;
    }

    NSString *sourceId = fromAppId;
    if ([fromProcessName isEqualToString:@"configd"]) {
        sourceId = @"com.apple.configd";
    }

    if (ShouldDeclineRequest(sourceId, toAppId)) {
        RecordRequest(sourceId, toAppId, YES);

        if (gBannerEnabled && fromAppName && toAppName) {
            NSString *primaryTitle =
                NSLocalizedStringFromTableInBundle(@"No Redirect", @"Tweak", NRUSupportBundle(), @"");
            NSString *secondaryFmt = NSLocalizedStringFromTableInBundle(@"“%@” is not allowed to open “%@”.", @"Tweak",
                                                                        NRUSupportBundle(), @"");

            if (primaryTitle && secondaryFmt) {
                NSString *secondaryTitle = [NSString stringWithFormat:secondaryFmt, fromAppName, toAppName];
                NSDictionary *userInfo = @{
                    @"primaryTitle" : primaryTitle,
                    @"secondaryTitle" : secondaryTitle,
                };
                [gMessagingCenter sendMessageName:@"PostDeniedBanner" userInfo:userInfo];
            }
        }

        if ([gUseHandledSimulationSources containsObject:sourceId]) {
            BOOL isStoreKitUI = [toAppId isEqualToString:@"com.apple.ios.StoreKitUIService"];
            if (isStoreKitUI) {
                [request declineWithReason:@"No Redirect (Handled)"];
                return NO;
            }

            BOOL isSafariUI = [toAppId isEqualToString:@"com.apple.SafariViewService"];
            if (isSafariUI) {
                HBLogDebug(@"Redirecting to Safari View Services (Fallback)");
                return %orig;
            }

            [request.applicationContext setBackground:YES];
            return %orig;
        }

        [request declineWithReason:@"No Redirect"];
        return NO;
    }

    RecordRequest(sourceId, toAppId, NO);
    return %orig;
}

%end

%end

%group NoRedirectSafari

%hook _SFBrowserContentViewController

- (void)viewWillAppear:(BOOL)arg1 {
    %orig;

    NSString *fromAppId = [self _hostApplicationBundleIdentifier];
    NSString *toAppId = @"com.apple.SafariViewService";

    if (ShouldDeclineRequest(fromAppId, toAppId)) {
        if ([gUseHandledSimulationSources containsObject:fromAppId]) {
            HBLogDebug(@"Dismissed Safari View Services (Handled)");
            [self _dismiss];
        }
    }
}

%end

%end

%group NoRedirectRunningBoard

%hook RBProcessManager

- (id)executeLaunchRequest:(RBSLaunchRequest *)request withError:(NSError **)errorPtr {
    id process = %orig;

    RBSProcessBundle *bundle = request.context.hostProcess.handle.bundle;
    NSString *fromAppId = bundle.identifier;
    if (!fromAppId) {
        return process;
    }

    NSString *toAppId = nil;
    RBSProcessIdentity *identity = request.context.identity;
    if (![identity respondsToSelector:@selector(xpcServiceIdentifier)]) {
        return process;
    }

    NSString *toXpcId = identity.xpcServiceIdentifier;
    if ([toXpcId hasPrefix:@"com.apple.AppStore."]) {
        toAppId = @"com.apple.AppStore";
    }
    if (!toAppId) {
        return process;
    }

    if ([fromAppId isEqualToString:toAppId]) {
        return process;
    }

    if (ShouldDeclineRequest(fromAppId, toAppId)) {
        RecordRequest(fromAppId, toAppId, YES);

        if ([bundle respondsToSelector:@selector(bundleInfoValueForKey:)]) {
            NSString *fromAppName = [bundle bundleInfoValueForKey:@"CFBundleDisplayName"];
            NSString *toAppName = @"App Store";

            if (gBannerEnabled && fromAppName && toAppName) {
                NSDictionary *userInfo = @{
                    @"fromAppName" : fromAppName,
                    @"toAppName" : toAppName,
                };
                [gMessagingCenter sendMessageName:@"PostDeniedBanner" userInfo:userInfo];
            }
        }

        if (errorPtr) {
            NSDictionary *userInfo = @{
                NSLocalizedDescriptionKey : @"Launch declined by No Redirect",
                NSLocalizedFailureReasonErrorKey :
                    [NSString stringWithFormat:@"%@ is not allowed to launch %@.", fromAppId, toAppId],
            };

            *errorPtr = [NSError errorWithDomain:@"com.82flex.noredirect" code:1 userInfo:userInfo];
        }

        return nil;
    }

    RecordRequest(fromAppId, toAppId, NO);
    return process;
}

%end

%end

%ctor {
    NSString *processName = [[NSProcessInfo processInfo] processName];

#if !TARGET_OS_SIMULATOR
    if ([processName isEqualToString:@"SafariViewService"]) {
        int ret;
#if THEOS_PACKAGE_SCHEME_ROOTHIDE
        ret = libSandy_applyProfile("NoRedirectSafari_RootHide");
#else
        ret = libSandy_applyProfile("NoRedirectSafari");
#endif
        if (ret == kLibSandyErrorXPCFailure) {
            HBLogError(@"Failed to apply libSandy profile");
            return;
        }
        gIsSafariViewService = YES;
    } else if ([processName isEqualToString:@"runningboardd"]) {
        int ret;
        ret = libSandy_applyProfile("NoRedirectUI");
        if (ret == kLibSandyErrorXPCFailure) {
            HBLogError(@"Failed to apply libSandy profile");
            return;
        }
        gIsRunningBoardDaemon = YES;
    }
#endif

    ReloadPrefs();
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        (CFNotificationCallback)ReloadPrefs,
        CFSTR("com.82flex.noredirectprefs/saved"),
        NULL,
        CFNotificationSuspensionBehaviorCoalesce
    );

    if ([processName isEqualToString:@"SpringBoard"] || [processName isEqualToString:@"runningboardd"]) {
        gMessagingCenter = [CPDistributedMessagingCenter centerNamed:@"com.82flex.noredirect.ui"];
    }

    if ([processName isEqualToString:@"SpringBoard"]) {
        [NoRedirectRecord clearAllRecordsBeforeBoot];
        %init(NoRedirectPrimary);
    } else if ([processName isEqualToString:@"runningboardd"]) {
        %init(NoRedirectRunningBoard);
    } else if ([processName isEqualToString:@"SafariViewService"]) {
        %init(NoRedirectSafari);
    }

    if (gMessagingCenter) {
        HBLogDebug(@"NoRedirect initialized in process %@ with messaging center %@", processName, gMessagingCenter);
    } else {
        HBLogDebug(@"NoRedirect initialized in process %@", processName);
    }
}