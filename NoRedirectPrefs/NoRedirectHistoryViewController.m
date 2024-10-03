#import <Foundation/Foundation.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSDateFormatter.h>
#import <Foundation/NSDictionary.h>
#import <MobileCoreServices/LSApplicationProxy.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>

#import "NoRedirectHistoryViewController.h"
#import "NoRedirectRecord.h"

@implementation NoRedirectHistoryViewController {
    UIBarButtonItem *_clearButton;
}

- (BOOL)shouldShowSubtitles {
    return YES;
}

+ (NSDateFormatter *)mediumDateFormatter {
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      formatter = [[NSDateFormatter alloc] init];
      formatter.dateStyle = NSDateFormatterMediumStyle;
      formatter.timeStyle = NSDateFormatterNoStyle;
    });
    return formatter;
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray<PSSpecifier *> *specifiers = [NSMutableArray array];

        NSString *dateString = nil;
        NSMutableDictionary<NSString *, LSApplicationProxy *> *cachedProxies = [NSMutableDictionary dictionary];
        NSArray<NoRedirectRecord *> *records = [NoRedirectRecord allRecords];
        for (NoRedirectRecord *record in records) {
            if (!record.source || !record.target) {
                continue;
            }

            LSApplicationProxy *srcProxy = cachedProxies[record.source];
            if (!srcProxy) {
                srcProxy = [LSApplicationProxy applicationProxyForIdentifier:record.source];
                if (srcProxy) {
                    cachedProxies[record.source] = srcProxy;
                }
            }
            if (!srcProxy || !srcProxy.localizedName) {
                continue;
            }

            LSApplicationProxy *targetProxy = cachedProxies[record.target];
            if (!targetProxy) {
                targetProxy = [LSApplicationProxy applicationProxyForIdentifier:record.target];
                if (targetProxy) {
                    cachedProxies[record.target] = targetProxy;
                }
            }
            if (!targetProxy || !targetProxy.localizedName) {
                continue;
            }

            PSSpecifier *specifier = [self createSpecifierForApplicationProxy:srcProxy];
            if (!specifier) {
                continue;
            }

            specifier.name =
                [NSString stringWithFormat:@"%@  ❯  %@", srcProxy.localizedName, targetProxy.localizedName];

            [specifier setProperty:record forKey:@"associatedRecord"];

            NSString *newDateString =
                [[NoRedirectHistoryViewController mediumDateFormatter] stringFromDate:record.createdAt];
            if (![dateString isEqualToString:newDateString]) {
                dateString = newDateString;

                PSSpecifier *dateSpecifier = [PSSpecifier preferenceSpecifierNamed:dateString
                                                                            target:nil
                                                                               set:nil
                                                                               get:nil
                                                                            detail:nil
                                                                              cell:PSGroupCell
                                                                              edit:nil];

                [specifiers addObject:dateSpecifier];
            }

            [specifiers addObject:specifier];
        }

        _specifiers = specifiers;
    }
    return _specifiers;
}

+ (NSDateFormatter *)shortDateTimeFormatter {
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      formatter = [[NSDateFormatter alloc] init];
      formatter.dateStyle = NSDateFormatterShortStyle;
      formatter.timeStyle = NSDateFormatterShortStyle;
    });
    return formatter;
}

- (NSString *)_subtitleForSpecifier:(PSSpecifier *)specifier {
    NoRedirectRecord *record = [specifier propertyForKey:@"associatedRecord"];
    if (record.declined) {
        return
            [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Declined on %@", @"History",
                                                                          [NSBundle bundleForClass:[self class]], nil),
                                       [[NoRedirectHistoryViewController shortDateTimeFormatter]
                                           stringFromDate:record.createdAt]];
    } else {
        return
            [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Redirected on %@", @"History",
                                                                          [NSBundle bundleForClass:[self class]], nil),
                                       [[NoRedirectHistoryViewController shortDateTimeFormatter]
                                           stringFromDate:record.createdAt]];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title =
        NSLocalizedStringFromTableInBundle(@"Redirect History", @"Root", [NSBundle bundleForClass:self.class], nil);

    _clearButton = [[UIBarButtonItem alloc]
        initWithTitle:NSLocalizedStringFromTableInBundle(@"Clear", @"History", [NSBundle bundleForClass:self.class],
                                                         nil)
                style:UIBarButtonItemStylePlain
               target:self
               action:@selector(clearHistory)];

    self.navigationItem.rightBarButtonItem = _clearButton;
}

- (void)clearHistory {
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:nil
                                            message:NSLocalizedStringFromTableInBundle(
                                                        @"Are you sure you want to clear the redirect history?",
                                                        @"History", [NSBundle bundleForClass:self.class], nil)
                                     preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTableInBundle(
                                                        @"Clear", @"History", [NSBundle bundleForClass:self.class], nil)
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *action) {
                                              [self realClearHistory];
                                            }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTableInBundle(
                                                        @"Cancel", @"Root", [NSBundle bundleForClass:self.class], nil)
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)realClearHistory {
    [NoRedirectRecord clearAllRecords];
    [self updateSpecifiers:[self specifiers] withSpecifiers:@[]];
}

@end