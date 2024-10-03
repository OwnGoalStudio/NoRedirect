#import "NoRedirectRecord.h"

#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <HBLog.h>
#import <QuartzCore/QuartzCore.h>
#import <sqlite3.h>

@implementation NoRedirectRecord

@synthesize declined = _declined;
@synthesize source = _source;
@synthesize target = _target;
@synthesize createdAt = _createdAt;

+ (sqlite3 *)sharedDatabase {
    static sqlite3 *db = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      NSString *libraryPath =
          [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
      NSString *preferencesPath = [libraryPath stringByAppendingPathComponent:@"Preferences"];
      NSString *databasePath = [preferencesPath stringByAppendingPathComponent:@"com.82flex.noredirect.db"];
      if (sqlite3_open([databasePath UTF8String], &db) == SQLITE_OK) {
          char *error;
          if (sqlite3_exec(db, "PRAGMA journal_mode=WAL;", NULL, NULL, &error) != SQLITE_OK) {
              HBLogError(@"Failed to set WAL mode: %s", error);
          }
          if (sqlite3_exec(db, "PRAGMA synchronous=NORMAL;", NULL, NULL, &error) != SQLITE_OK) {
              HBLogError(@"Failed to set synchronous mode: %s", error);
          }
          if (sqlite3_exec(db,
                           "CREATE TABLE IF NOT EXISTS records (id INTEGER PRIMARY KEY AUTOINCREMENT, declined "
                           "INTEGER, source TEXT, target TEXT, created_at INTEGER);",
                           NULL, NULL, &error) != SQLITE_OK) {
              HBLogError(@"Failed to create table: %s", error);
          }
      } else {
          HBLogError(@"Failed to open database: %s", sqlite3_errmsg(db));
      }
    });
    return db;
}

+ (NSArray<NoRedirectRecord *> *)allRecords {
    NSMutableArray<NoRedirectRecord *> *records = [NSMutableArray array];
    sqlite3 *db = [self sharedDatabase];
    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(db, "SELECT * FROM records ORDER BY created_at DESC;", -1, &stmt, NULL) == SQLITE_OK) {
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            NoRedirectRecord *record = [[NoRedirectRecord alloc] init];
            record->_declined = (BOOL)sqlite3_column_int(stmt, 1);
            record->_source = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 2)];
            record->_target = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 3)];
            record->_createdAt = [NSDate dateWithTimeIntervalSince1970:sqlite3_column_int(stmt, 4)];
            [records addObject:record];
        }
        sqlite3_finalize(stmt);
    }
    return records;
}

+ (void)insertRecord:(BOOL)declined source:(NSString *)sourceIdentifier target:(NSString *)targetIdentifier {
    sqlite3 *db = [self sharedDatabase];
    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(db, "INSERT INTO records (declined, source, target, created_at) VALUES (?, ?, ?, ?);", -1,
                           &stmt, NULL) == SQLITE_OK) {
        sqlite3_bind_int(stmt, 1, declined);
        sqlite3_bind_text(stmt, 2, [sourceIdentifier UTF8String], -1, SQLITE_STATIC);
        sqlite3_bind_text(stmt, 3, [targetIdentifier UTF8String], -1, SQLITE_STATIC);
        sqlite3_bind_int(stmt, 4, (int)[[NSDate date] timeIntervalSince1970]);
        if (sqlite3_step(stmt) != SQLITE_DONE) {
            HBLogError(@"Failed to insert record: %s", sqlite3_errmsg(db));
        }
        sqlite3_finalize(stmt);
    } else {
        HBLogError(@"Failed to prepare statement: %s", sqlite3_errmsg(db));
    }
}

+ (void)clearAllRecordsBeforeBoot {
    CFTimeInterval bootTime = CACurrentMediaTime();
    sqlite3 *db = [self sharedDatabase];
    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(db, "DELETE FROM records WHERE created_at < ?;", -1, &stmt, NULL) == SQLITE_OK) {
        sqlite3_bind_int(stmt, 1, (int)bootTime);
        if (sqlite3_step(stmt) != SQLITE_DONE) {
            HBLogError(@"Failed to delete records: %s", sqlite3_errmsg(db));
        }
        sqlite3_finalize(stmt);
    } else {
        HBLogError(@"Failed to prepare statement: %s", sqlite3_errmsg(db));
    }
}

@end