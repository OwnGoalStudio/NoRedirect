#import <Foundation/Foundation.h>
#import <MobileCoreServices/LSApplicationProxy.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>

#import "NoRedirectHistoryViewController.h"

@implementation NoRedirectHistoryViewController {
    UIBarButtonItem *_clearButton;
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
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:nil
                         message:NSLocalizedStringFromTableInBundle(
                                     @"Are you sure you want to clear the redirect history?", @"History",
                                     [NSBundle bundleForClass:self.class], nil)
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
    // Clear history
}

@end