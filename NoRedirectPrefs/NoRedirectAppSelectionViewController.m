#import <AltList/AltList.h>
#import <Foundation/Foundation.h>
#import <HBLog.h>
#import <Preferences/PSSpecifier.h>

#import "NoRedirectAppSelectionViewController.h"

@implementation NoRedirectAppSelectionViewController {
    PSSpecifier *_primarySpecifier;
    NSMutableArray<NSString *> *_selectedApplications;
    UIBarButtonItem *_cancelButton;
    UIBarButtonItem *_saveButton;
    BOOL _isChanged;
}

- (PSSpecifier *)primarySpecifier {
    if (!_primarySpecifier) {
        _primarySpecifier = [PSSpecifier preferenceSpecifierNamed:@"Selected Applications"
                                                           target:self
                                                              set:@selector(setPreferenceValue:specifier:)
                                                              get:@selector(readPreferenceValue:)
                                                           detail:nil
                                                             cell:PSLinkListCell
                                                             edit:nil];
        [_primarySpecifier setProperty:[NSString stringWithFormat:@"%@/%@", self.preferenceKey, self.applicationID]
                                forKey:@"key"];
        [_primarySpecifier setProperty:@"com.82flex.noredirectprefs" forKey:@"defaults"];
        [_primarySpecifier setProperty:@"com.82flex.noredirectprefs/saved" forKey:@"PostNotification"];
    }
    return _primarySpecifier;
}

- (void)readSelectedApplications {
    _selectedApplications = [NSMutableArray arrayWithArray:([super readPreferenceValue:[self primarySpecifier]] ?: @[])];
}

- (void)writeSelectedApplications {
    [super setPreferenceValue:(_selectedApplications ?: @[]) specifier:[self primarySpecifier]];
}

- (void)setApplicationEnabled:(NSNumber *)enabledNum specifier:(PSSpecifier *)specifier {
    if (!specifier.identifier) {
        return;
    }
    if ([enabledNum boolValue]) {
        [_selectedApplications addObject:specifier.identifier];
    } else {
        [_selectedApplications removeObject:specifier.identifier];
    }
    _isChanged = YES;
    [self reloadSaveButton];
}

- (id)readApplicationEnabled:(PSSpecifier *)specifier {
    return @([_selectedApplications containsObject:specifier.identifier]);
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _cancelButton = [[UIBarButtonItem alloc]
        initWithTitle:NSLocalizedStringFromTableInBundle(@"Cancel", @"App", [NSBundle bundleForClass:self.class], nil)
                style:UIBarButtonItemStylePlain
               target:self
               action:@selector(performDismissal:)];
    self.navigationItem.leftBarButtonItem = _cancelButton;
    
    _saveButton = [[UIBarButtonItem alloc]
        initWithTitle:NSLocalizedStringFromTableInBundle(@"Save", @"App", [NSBundle bundleForClass:self.class], nil)
                style:UIBarButtonItemStyleDone
               target:self
               action:@selector(performSave:)];
    _saveButton.enabled = NO;
    self.navigationItem.rightBarButtonItem = _saveButton;

    [self readSelectedApplications];
}

- (void)performDismissal:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)performSave:(id)sender {
    [self writeSelectedApplications];
    [self.presentingParentController reloadSpecifiers];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)reloadSaveButton {
    [_saveButton setEnabled:_isChanged];
}

@end