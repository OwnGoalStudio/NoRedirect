#import <AltList/AltList.h>
#import <Foundation/Foundation.h>
#import <MobileCoreServices/LSApplicationProxy.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>

#import "LSApplicationProxy+AltList.h"
#import "NoRedirectAppSelectionViewController.h"
#import "NoRedirectAppSpecificViewController.h"

@implementation NoRedirectAppSpecificViewController {
    NSString *_applicationName;
    PSSpecifier *_blockedSpecifier;
    NSMutableArray<NSString *> *_blockedApplications;
    NSMutableArray<NSString *> *_blockedApplicationNames;
    PSSpecifier *_bypassedSpecifier;
    NSMutableArray<NSString *> *_bypassedApplications;
    NSMutableArray<NSString *> *_bypassedApplicationNames;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    PSListController *topVC = (PSListController *)self.navigationController.topViewController;
    if ([topVC respondsToSelector:@selector(reloadSpecifier:)]) {
        [topVC reloadSpecifier:[self specifier]];
    }
}

- (NSString *)applicationName {
    if (!_applicationName) {
        LSApplicationProxy *appProxy = [LSApplicationProxy applicationProxyForIdentifier:self.applicationID];
        _applicationName = appProxy.atl_nameToDisplay;
    }
    return _applicationName ?: self.specifier.name;
}

- (void)setSpecifier:(PSSpecifier *)specifier {
    [super setSpecifier:specifier];

    NSString *appId = [specifier propertyForKey:@"applicationIdentifier"];
    self.applicationID = appId;

    [self setTitle:[self applicationName]];
}

- (NSMutableArray *)loadSpecifiersFromPlistName:(NSString *)plistName target:(id)target {
    NSMutableArray *specifiers = [super loadSpecifiersFromPlistName:plistName target:target];
    if (!self.title || self.title.length == 0) {
        [self setTitle:[self applicationName]];
    }
    return specifiers;
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specifiers = [self loadSpecifiersFromPlistName:[self plistName] target:self];

        PSSpecifier *groupCustomBlocksSpecifier = nil;
        PSSpecifier *addCustomBlockSpecifier = nil;
        PSSpecifier *groupCustomBypassesSpecifier = nil;
        PSSpecifier *addCustonBypassSpecifier = nil;

        for (PSSpecifier *specifier in specifiers) {
            NSString *action = [specifier propertyForKey:@"action"];
            NSString *key = [specifier propertyForKey:@"key"];

            NSString *mixedKey = [NSString stringWithFormat:@"%@/%@", key, self.applicationID];
            [specifier setProperty:mixedKey forKey:@"key"];

            if ([action isEqualToString:@"addCustomBlock"]) {
                addCustomBlockSpecifier = specifier;
            } else if ([action isEqualToString:@"addCustomBypass"]) {
                addCustonBypassSpecifier = specifier;
            } else if ([key isEqualToString:@"GroupCustomBlocks"]) {
                groupCustomBlocksSpecifier = specifier;
            } else if ([key isEqualToString:@"GroupCustomBypasses"]) {
                groupCustomBypassesSpecifier = specifier;
            }
        }

        NSInteger blockInsertionPoint = [specifiers indexOfObject:addCustomBlockSpecifier];
        NSInteger bypassInsertionPoint = [specifiers indexOfObject:addCustonBypassSpecifier];

        [self readBlockedApplications];
        [self readBypassedApplications];

        _blockedApplicationNames = [NSMutableArray arrayWithCapacity:_blockedApplications.count];
        _bypassedApplicationNames = [NSMutableArray arrayWithCapacity:_bypassedApplications.count];

        NSMutableArray<PSSpecifier *> *blockedSpecifiers = [NSMutableArray array];
        for (NSString *blockedApp in _blockedApplications) {
            LSApplicationProxy *appProxy = [LSApplicationProxy applicationProxyForIdentifier:blockedApp];
            if (!appProxy) {
                continue;
            }

            PSSpecifier *appSpec = [self createSpecifierForApplicationProxy:appProxy];
            if (!appSpec) {
                continue;
            }

            [blockedSpecifiers addObject:appSpec];
            if (appSpec.name) {
                [_blockedApplicationNames addObject:appSpec.name];
            }
        }
        [blockedSpecifiers sortUsingComparator:^NSComparisonResult(PSSpecifier *obj1, PSSpecifier *obj2) {
          return [obj1.name localizedStandardCompare:obj2.name];
        }];

        NSMutableArray<PSSpecifier *> *bypassedSpecifiers = [NSMutableArray array];
        for (NSString *bypassedApp in _bypassedApplications) {
            LSApplicationProxy *appProxy = [LSApplicationProxy applicationProxyForIdentifier:bypassedApp];
            if (!appProxy) {
                continue;
            }

            PSSpecifier *appSpec = [self createSpecifierForApplicationProxy:appProxy];
            if (!appSpec) {
                continue;
            }

            [bypassedSpecifiers addObject:appSpec];
            if (appSpec.name) {
                [_bypassedApplicationNames addObject:appSpec.name];
            }
        }
        [bypassedSpecifiers sortUsingComparator:^NSComparisonResult(PSSpecifier *obj1, PSSpecifier *obj2) {
          return [obj1.name localizedStandardCompare:obj2.name];
        }];

        [groupCustomBlocksSpecifier setProperty:[self blockedFooterText] forKey:@"footerText"];
        [groupCustomBypassesSpecifier setProperty:[self bypassedFooterText] forKey:@"footerText"];

        if (blockedSpecifiers.count > 0) {
            addCustomBlockSpecifier.name = NSLocalizedStringFromTableInBundle(
                @"Edit Custom Block…", @"App", [NSBundle bundleForClass:self.class], nil);
        }

        if (bypassedSpecifiers.count > 0) {
            addCustonBypassSpecifier.name = NSLocalizedStringFromTableInBundle(
                @"Edit Custom Bypass…", @"App", [NSBundle bundleForClass:self.class], nil);
        }

        [specifiers insertObjects:bypassedSpecifiers
                        atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(bypassInsertionPoint,
                                                                                     bypassedSpecifiers.count)]];
        [specifiers insertObjects:blockedSpecifiers
                        atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(blockInsertionPoint,
                                                                                     blockedSpecifiers.count)]];

        _specifiers = specifiers;
    }
    return _specifiers;
}

- (PSSpecifier *)blockedSpecifier {
    if (!_blockedSpecifier) {
        _blockedSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Blocked Applications"
                                                           target:self
                                                              set:@selector(setPreferenceValue:specifier:)
                                                              get:@selector(readPreferenceValue:)
                                                           detail:nil
                                                             cell:PSLinkListCell
                                                             edit:nil];
        [_blockedSpecifier setProperty:[NSString stringWithFormat:@"%@/%@", kNoRedirectKeyCustomBlockedApplications,
                                                                  self.applicationID]
                                forKey:@"key"];
        [_blockedSpecifier setProperty:@"com.82flex.noredirectprefs" forKey:@"defaults"];
    }
    return _blockedSpecifier;
}

- (void)readBlockedApplications {
    _blockedApplications = [NSMutableArray arrayWithArray:([super readPreferenceValue:[self blockedSpecifier]] ?: @[])];
}

- (PSSpecifier *)bypassedSpecifier {
    if (!_bypassedSpecifier) {
        _bypassedSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Bypassed Applications"
                                                            target:self
                                                               set:@selector(setPreferenceValue:specifier:)
                                                               get:@selector(readPreferenceValue:)
                                                            detail:nil
                                                              cell:PSLinkListCell
                                                              edit:nil];
        [_bypassedSpecifier setProperty:[NSString stringWithFormat:@"%@/%@", kNoRedirectKeyCustomBypassedApplications,
                                                                   self.applicationID]
                                 forKey:@"key"];
        [_bypassedSpecifier setProperty:@"com.82flex.noredirectprefs" forKey:@"defaults"];
    }
    return _bypassedSpecifier;
}

- (void)readBypassedApplications {
    _bypassedApplications =
        [NSMutableArray arrayWithArray:([super readPreferenceValue:[self bypassedSpecifier]] ?: @[])];
}

- (NSString *)plistName {
    return @"App";
}

- (NSString *)blockedFooterText {
    NSString *what;
    if (_blockedApplicationNames.count == 1) {
        what = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"“%@”", @"App",
                                                                             [NSBundle bundleForClass:self.class], nil),
                                          [_blockedApplicationNames firstObject]];
    } else if (_blockedApplications.count == 2) {
        what =
            [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"“%@” and “%@”", @"App",
                                                                          [NSBundle bundleForClass:self.class], nil),
                                       [_blockedApplicationNames firstObject], [_blockedApplicationNames lastObject]];
    } else if (_blockedApplications.count > 2) {
        NSString *what2;
        if (_blockedApplications.count == 3) {
            what2 = [NSString
                stringWithFormat:NSLocalizedStringFromTableInBundle(@"%lu other application", @"App",
                                                                    [NSBundle bundleForClass:self.class], nil),
                                 _blockedApplications.count - 2];
        } else {
            what2 = [NSString
                stringWithFormat:NSLocalizedStringFromTableInBundle(@"%lu other applications", @"App",
                                                                    [NSBundle bundleForClass:self.class], nil),
                                 _blockedApplications.count - 2];
        }
        what = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"“%@”, “%@” and %@", @"App",
                                                                             [NSBundle bundleForClass:self.class], nil),
                                          [_blockedApplicationNames firstObject],
                                          [_blockedApplicationNames objectAtIndex:1], what2];
    } else {
        what = nil;
    }
    if (!what) {
        return @"";
    }
    return [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"“%@” is blocked from launching %@.", @"App",
                                                                         [NSBundle bundleForClass:self.class], nil),
                                      _applicationName, what];
}

- (NSString *)bypassedFooterText {
    NSString *what;
    if (_bypassedApplications.count == 1) {
        what = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"“%@”", @"App",
                                                                             [NSBundle bundleForClass:self.class], nil),
                                          [_bypassedApplicationNames firstObject]];
    } else if (_bypassedApplications.count == 2) {
        what =
            [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"“%@” and “%@”", @"App",
                                                                          [NSBundle bundleForClass:self.class], nil),
                                       [_bypassedApplicationNames firstObject], [_bypassedApplicationNames lastObject]];
    } else if (_bypassedApplications.count > 2) {
        NSString *what2;
        if (_bypassedApplications.count == 3) {
            what2 = [NSString
                stringWithFormat:NSLocalizedStringFromTableInBundle(@"%lu other application", @"App",
                                                                    [NSBundle bundleForClass:self.class], nil),
                                 _bypassedApplications.count - 2];
        } else {
            what2 = [NSString
                stringWithFormat:NSLocalizedStringFromTableInBundle(@"%lu other applications", @"App",
                                                                    [NSBundle bundleForClass:self.class], nil),
                                 _bypassedApplications.count - 2];
        }
        what = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"“%@”, “%@” and %@", @"App",
                                                                             [NSBundle bundleForClass:self.class], nil),
                                          [_bypassedApplicationNames firstObject],
                                          [_bypassedApplicationNames objectAtIndex:1], what2];
    } else {
        what = nil;
    }
    if (!what) {
        return @"";
    }
    return [NSString
        stringWithFormat:NSLocalizedStringFromTableInBundle(
                             @"“%@” is always allowed to be launched by %@. These rules have the highest priority.",
                             @"App", [NSBundle bundleForClass:self.class], nil),
                         _applicationName, what];
}

- (void)addCustomBlock {
    [self customSelectionWithKey:kNoRedirectKeyCustomBlockedApplications];
}

- (void)addCustomBypass {
    [self customSelectionWithKey:kNoRedirectKeyCustomBypassedApplications];
}

- (void)customSelectionWithKey:(NSString *)prefKey {
    NoRedirectAppSelectionViewController *selectionCtrl =
        [[NoRedirectAppSelectionViewController alloc] initWithSections:@[
            [ATLApplicationSection applicationSectionWithDictionary:@{
                @"sectionType" : kApplicationSectionTypeUser,
            }],
            [ATLApplicationSection applicationSectionWithDictionary:@{
                @"sectionType" : kApplicationSectionTypeSystem,
            }],
        ]];

    selectionCtrl.applicationID = self.applicationID;
    selectionCtrl.showIdentifiersAsSubtitle = YES;
    selectionCtrl.useSearchBar = YES;
    selectionCtrl.hideSearchBarWhileScrolling = YES;
    selectionCtrl.includeIdentifiersInSearch = YES;
    if ([selectionCtrl respondsToSelector:@selector(highlightSearchText)]) {
        selectionCtrl.highlightSearchText = YES;
    }
    selectionCtrl.title = _applicationName;
    selectionCtrl.presentingParentController = self;
    selectionCtrl.preferenceKey = prefKey;

    UINavigationController *navCtrl = [[UINavigationController alloc] initWithRootViewController:selectionCtrl];
    [navCtrl setModalInPresentation:YES];
    [self presentViewController:navCtrl animated:YES completion:nil];
}

@end