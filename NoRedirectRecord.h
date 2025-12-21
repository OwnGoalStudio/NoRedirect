#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NoRedirectRecord : NSObject

@property(nonatomic, assign, readonly) BOOL declined;
@property(nonatomic, copy, readonly) NSString *source;
@property(nonatomic, copy, readonly) NSString *target;
@property(nonatomic, copy, readonly) NSDate *createdAt;

- (instancetype)init NS_UNAVAILABLE;
- (BOOL)isSourceTrusted;
- (NSString *)sourceIcon;

+ (NSArray<NoRedirectRecord *> *)allRecords;
+ (NSInteger)numberOfRecords;
+ (void)insertRecord:(BOOL)declined source:(NSString *)sourceIdentifier target:(NSString *)targetIdentifier;
+ (void)clearAllRecordsBeforeBoot;
+ (void)clearAllRecords;

@end

NS_ASSUME_NONNULL_END