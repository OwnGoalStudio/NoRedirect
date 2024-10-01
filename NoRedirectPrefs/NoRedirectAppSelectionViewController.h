#import <AltList/AltList.h>
#import <Preferences/PSListController.h>

#define kNoRedirectKeyCustomBlockedApplications @"CustomBlockedApplications"
#define kNoRedirectKeyCustomBypassedApplications @"CustomBypassedApplications"

@interface NoRedirectAppSelectionViewController : ATLApplicationListMultiSelectionController
@property(nonatomic, copy) NSString *applicationID;
@property(nonatomic, copy) NSString *preferenceKey;
@property(nonatomic, weak) PSListController *presentingParentController;
@end