#import <AppSupport/CPDistributedMessagingCenter.h>
#import <Foundation/Foundation.h>

#import <HBLog.h>
#import <dlfcn.h>
#import <libroot.h>
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

+ (NSBundle *)nru_supportBundle {
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
        return;
    }

    if (@available(iOS 17, *)) {
        static _UISystemBannerRequest *bannerRequest;
        bannerRequest = [[objc_getClass("_UISystemBannerRequest") alloc] init];
        bannerRequest.primaryTitleText = primaryTitle;
        bannerRequest.secondaryTitleText = secondaryTitle;
        bannerRequest.bannerTimeoutDuration = 4.0;
        [bannerRequest postBanner];
    } else {
        xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
        xpc_dictionary_set_double(message, "BUISKeyBannerTimeout", 4.0);
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
