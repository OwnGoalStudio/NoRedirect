#import <AppSupport/CPDistributedMessagingCenter.h>
#import <Foundation/Foundation.h>

#import <HBLog.h>
#import <dlfcn.h>
#import <libroot.h>
#import <mach-o/dyld.h>
#import <objc/runtime.h>
#import <xpc/xpc.h>

@interface _UISystemBannerRequest : NSObject
@property(nonatomic, copy) NSString *primaryTitleText;
@property(nonatomic, copy) NSString *secondaryTitleText;
@property(nonatomic, assign) NSTimeInterval bannerTimeoutDuration;
@property(nonatomic, assign) CGFloat preferredMinimumBannerWidth;
@property(nonatomic, assign) CGFloat preferredMaximumBannerWidth;
- (void)postBanner;
@end

typedef xpc_connection_t (*xpc_connection_create_mach_service_t)(const char *name, dispatch_queue_t _Nullable targetq,
                                                                 uint64_t flags);

static void NRUSendBannerMessage(xpc_object_t message) {
    static xpc_connection_t sConn = nil;
    if (!sConn) {
        static xpc_connection_create_mach_service_t xpc_connection_create_mach_service_ios = NULL;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
          xpc_connection_create_mach_service_ios =
              (xpc_connection_create_mach_service_t)dlsym(RTLD_DEFAULT, "xpc_connection_create_mach_service");
        });
        if (!xpc_connection_create_mach_service_ios) {
            HBLogError(@"Failed to find xpc_connection_create_mach_service symbol");
            return;
        }
        xpc_connection_t connection = xpc_connection_create_mach_service_ios("com.apple.BluetoothUIService", NULL, 0);
        xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {
          if (xpc_get_type(event) == XPC_TYPE_ERROR) {
              if (event == XPC_ERROR_CONNECTION_INTERRUPTED || event == XPC_ERROR_CONNECTION_INVALID) {
                  HBLogError(@"XPC connection interrupted or invalid, resetting connection");
                  sConn = nil;
              }
          }
        });
        xpc_connection_resume(connection);
        sConn = connection;
    }
    if (sConn) {
        xpc_connection_send_message(sConn, message);
    }
}

#pragma mark - Bundle

static NSString *nruExecutablePath(void) {
    static NSString *sPath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      // Resolve executable path
      uint32_t sz = 0;
      _NSGetExecutablePath(NULL, &sz); // query size
      char *exeBuf = (char *)malloc(sz > 0 ? sz : PATH_MAX);
      if (!exeBuf)
          return;
      if (_NSGetExecutablePath(exeBuf, &sz) != 0) {
          // Fallback: leave exeBuf as-is
      }

      // Canonicalize
      char realBuf[PATH_MAX];
      const char *exePath = realpath(exeBuf, realBuf) ? realBuf : exeBuf;
      NSString *exe = [NSString stringWithUTF8String:exePath ? exePath : ""];
      free(exeBuf);

      sPath = exe ?: [[NSProcessInfo processInfo] arguments][0];
    });
    return sPath;
}

static NSBundle *nruResourceBundle(void) {
    static NSBundle *sBundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      NSString *exe = nruExecutablePath();
      NSString *exeDir = [exe stringByDeletingLastPathComponent];
      NSString *resRel = @"../../Library/PreferenceBundles/NoRedirectPrefs.bundle";
      NSString *resPath = [[exeDir stringByAppendingPathComponent:resRel] stringByStandardizingPath];
      NSBundle *resBundle = resPath ? [NSBundle bundleWithPath:resPath] : nil;
      if (!resBundle)
          return;

      sBundle = resBundle;
    });
    return sBundle;
}

static NSBundle *nruLocalizationBundle(void) {
    static NSBundle *sBundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      NSBundle *resBundle = nruResourceBundle();

      NSArray<NSString *> *languages = [[NSUserDefaults standardUserDefaults] objectForKey:@"AppleLanguages"] ?: @"en";

      NSString *localizablePath = nil;
      for (NSString *localization in [NSBundle preferredLocalizationsFromArray:[resBundle localizations]
                                                                forPreferences:languages]) {
          localizablePath = [resBundle pathForResource:@"Localizable"
                                                ofType:@"strings"
                                           inDirectory:nil
                                       forLocalization:localization];
          if (localizablePath && localizablePath.length > 0)
              break;
      }

      NSString *lprojPath = [localizablePath stringByDeletingLastPathComponent];
      if (lprojPath && lprojPath.length > 0) {
          resBundle = [NSBundle bundleWithPath:lprojPath];
      }

      sBundle = resBundle;
    });
    return sBundle;
}

@interface NoRedirectViewService : NSObject
@end

@implementation NoRedirectViewService

+ (void)load {
    [self sharedInstance];
}

+ (instancetype)sharedInstance {
    static dispatch_once_t once = 0;
    __strong static NoRedirectViewService *sharedInstance = nil;
    dispatch_once(&once, ^{
      sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if ((self = [super init])) {
        // ...
        // Center name must be unique, recommend using application identifier.
        CPDistributedMessagingCenter *messagingCenter =
            [CPDistributedMessagingCenter centerNamed:@"com.82flex.noredirect.ui"];
        [messagingCenter runServerOnCurrentThread];

        // Register Messages
        [messagingCenter registerForMessageName:@"PostDeniedBanner"
                                         target:self
                                       selector:@selector(handleMessageNamed:withUserInfo:)];
    }

    return self;
}

- (void)handleMessageNamed:(NSString *)name withUserInfo:(NSDictionary *)userInfo {
    if (![name isEqualToString:@"PostDeniedBanner"]) {
        return;
    }
    if (!userInfo) {
        return;
    }

    NSString *primaryTitle = userInfo[@"primaryTitle"];
    NSString *secondaryTitle = userInfo[@"secondaryTitle"];
    if (![primaryTitle isKindOfClass:[NSString class]] || ![secondaryTitle isKindOfClass:[NSString class]]) {
        NSString *fromAppName = userInfo[@"fromAppName"];
        NSString *toAppName = userInfo[@"toAppName"];
        if (![fromAppName isKindOfClass:[NSString class]] || ![toAppName isKindOfClass:[NSString class]]) {
            return;
        }

        NSBundle *localizationBundle = nruLocalizationBundle();
        primaryTitle = NSLocalizedStringFromTableInBundle(@"No Redirect", @"Tweak", localizationBundle, @"");
        NSString *secondaryFmt =
            NSLocalizedStringFromTableInBundle(@"“%@” is not allowed to open “%@”.", @"Tweak", localizationBundle, @"");
        if (!primaryTitle || !secondaryFmt) {
            return;
        }

        secondaryTitle = [NSString stringWithFormat:secondaryFmt, fromAppName, toAppName];
    }

    // Calculate banner timeout based on text length
    NSTimeInterval bannerTimeout;
    bannerTimeout = MIN(MAX((primaryTitle.length + secondaryTitle.length) * 0.1, 4.0), 10.0);

    if (@available(iOS 17, *)) {
        static _UISystemBannerRequest *bannerRequest;
        bannerRequest = [[objc_getClass("_UISystemBannerRequest") alloc] init];
        bannerRequest.primaryTitleText = primaryTitle;
        bannerRequest.secondaryTitleText = secondaryTitle;
        bannerRequest.bannerTimeoutDuration = bannerTimeout;
        [bannerRequest postBanner];
    } else {
        // Not yet implemented for iOS versions below 17 with SBUIIsSystemApertureEnabled
        // Which means no banner will be shown on iPhone with Dynamic Island
        xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
        xpc_dictionary_set_double(message, "BUISKeyBannerTimeout", bannerTimeout);
        xpc_dictionary_set_string(message, "BUISKeyType", "BUISKeyArgType");
        xpc_dictionary_set_string(message, "BUISKeyCCText", [primaryTitle UTF8String]);
        xpc_dictionary_set_string(message, "BUISKeyCCItemsText", [secondaryTitle UTF8String]);
        NRUSendBannerMessage(message);
    }
}

@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        [[NSRunLoop currentRunLoop] run];
    }
    return EXIT_SUCCESS;
}
