#import <AltList/AltList.h>
#import <Foundation/Foundation.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>

#import "NoRedirectAppListController.h"

@implementation NoRedirectAppListController

- (NSString *)previewStringForApplicationWithIdentifier:(NSString *)applicationID {
    static NSUserDefaults *defaults = nil;
    if (!defaults) {
        defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.82flex.noredirectprefs"];
    }

    BOOL hasBeenModified = NO;
    NSString *appSuffix = [NSString stringWithFormat:@"/%@", applicationID];
    NSDictionary *settings = [defaults dictionaryRepresentation];
    for (NSString *key in settings) {
        if ([key hasSuffix:appSuffix]) {
            id value = [defaults objectForKey:key];
            if ([value isKindOfClass:[NSNumber class]] && [value boolValue]) {
                hasBeenModified = YES;
                break;
            }
            else if ([value isKindOfClass:[NSArray class]] && [value count] > 0) {
                hasBeenModified = YES;
                break;
            }
        }
    }

    if (hasBeenModified) {
        return NSLocalizedStringFromTableInBundle(@"Modified", @"App", [NSBundle bundleForClass:self.class], nil);
    }

    return nil;
}

@end