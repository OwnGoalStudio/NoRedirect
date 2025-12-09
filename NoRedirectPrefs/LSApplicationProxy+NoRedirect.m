#import "LSApplicationProxy+NoRedirect.h"

@interface LSApplicationProxy_NoRedirect_Stub : NSObject
@end

@implementation LSApplicationProxy_NoRedirect_Stub
@end

@implementation LSApplicationProxy (NoRedirect)

- (NSString *)nrt_nameToDisplay {
    if ([[self atl_bundleIdentifier] isEqualToString:@"com.apple.springboard"]) {
        return NSLocalizedStringFromTableInBundle(@"Home Screen", @"History", [NSBundle bundleForClass:[LSApplicationProxy_NoRedirect_Stub class]], nil);
    } else {
        return [self atl_nameToDisplay];
    }
}

@end
