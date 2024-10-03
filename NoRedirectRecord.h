#import <Foundation/Foundation.h>

@interface NoRedirectRecord : NSObject

@property(nonatomic, assign, readonly) BOOL declined;
@property(nonatomic, copy, readonly) NSString *source;
@property(nonatomic, copy, readonly) NSString *target;
@property(nonatomic, copy, readonly) NSDate *createdAt;

- (instancetype)init NS_UNAVAILABLE;
+ (NSArray<NoRedirectRecord *> *)allRecords;
+ (void)insertRecord:(BOOL)declined source:(NSString *)sourceIdentifier target:(NSString *)targetIdentifier;
+ (void)clearAllRecordsBeforeBoot;
+ (void)clearAllRecords;

@end