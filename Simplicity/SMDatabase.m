//
//  SMDatabase.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/14/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <sqlite3.h>

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMPreferencesController.h"
#import "SMFolderDesc.h"
#import "SMAddress.h"
#import "SMMessage.h"
#import "SMOutgoingMessage.h"
#import "SMMessageBuilder.h"
#import "SMMessageThreadDescriptor.h"
#import "SMMessageThreadDescriptorEntry.h"
#import "SMCompression.h"
#import "SMThreadSafeOperationQueue.h"
#import "SMOperationQueue.h"
#import "SMTextMessage.h"
#import "SMSearchExpressionKind.h"
#import "SMSearchToken.h"
#import "SMDatabase.h"

//#define CHECK_DATABASE

static const NSUInteger HEADERS_BODIES_RECLAIM_RATIO = 30; // TODO: too small for large databases!!!
static const NSUInteger BODIES_COUNT_RECLAIM_STEP = 50; // TODO: too small for large databases!!!
static const NSUInteger HEADERS_COUNT_RECLAIM_STEP = BODIES_COUNT_RECLAIM_STEP * HEADERS_BODIES_RECLAIM_RATIO;

typedef NS_ENUM(NSInteger, DBFailureKind) {
    DBFailure_NonCriticalDataNotFound,
    DBFailure_CriticalDataNotFound,
    DBFailure_LibraryCriticalError,
    DBFailure_Busy,
    DBFailure_WriteError,
};

typedef NS_ENUM(NSInteger, DBOpenMode) {
    DBOpenMode_ReadWrite,
    DBOpenMode_Read,
};

@interface FolderWithCounts : NSObject
@property NSUInteger folderId;
@property NSUInteger bodiesCount;
@property NSUInteger headersCount;
- (id)initWithFolderId:(NSUInteger)folderId headersCount:(NSUInteger)headersCount bodiesCount:(NSUInteger)bodiesCount;
@end

@implementation FolderWithCounts
- (id)initWithFolderId:(NSUInteger)folderId headersCount:(NSUInteger)headersCount bodiesCount:(NSUInteger)bodiesCount {
    self = [super init];
    if(self) {
        _folderId = folderId;
        _headersCount = headersCount;
        _bodiesCount = bodiesCount;
    }
    return self;
}
@end

@implementation SMDatabaseOp {
    volatile int32_t _cancelCount;
}

- (void)cancel {
    OSAtomicIncrement32(&_cancelCount);
}

- (BOOL)cancelled {
    // Stupid memory read w/o barrier.
    // Should be enough for non-critical cancellation.
    return _cancelCount != 0;
}

@end

@implementation SMDatabase {
    NSString *_dbFilePath;
    dispatch_queue_t _serialQueue;
    int32_t _serialQueueLength;
    int _nextFolderId;
    NSMutableDictionary *_folderIds;
    NSMutableDictionary *_folderNames;
    NSMutableDictionary *_messagesWithBodies;
    BOOL _dbInvalid;
    BOOL _dbMustBeReset;
    SMThreadSafeOperationQueue *_urgentTaskQueue;
}

- (id)initWithFilePath:(NSString*)dbFilePath {
    self = [self init];
    
    if(self) {
        _serialQueue = dispatch_queue_create("com.simplicity.Simplicity.serialDatabaseQueue", DISPATCH_QUEUE_SERIAL);
        _urgentTaskQueue = [[SMThreadSafeOperationQueue alloc] init];
        _messagesWithBodies = [NSMutableDictionary dictionary];
        _dbFilePath = dbFilePath;

#ifdef CHECK_DATABASE
        [self checkDatabase:_dbFilePath];
#endif
        [self initDatabase:_dbFilePath];
        
        if(_dbInvalid) {
            [self resetDatabase:_dbFilePath];
            [self initDatabase:_dbFilePath];
        }
    }
    
    return self;
}

- (void)triggerDBFailureWithSQLiteError:(int)sqliteError {
    if(sqliteError == SQLITE_BUSY) {
        SM_LOG_ERROR(@"Database '%@' is busy.", _dbFilePath);

        [self triggerDBFailure:DBFailure_Busy];
    }
    else {
        SM_LOG_ERROR(@"Database '%@' error %d.", _dbFilePath, sqliteError);

        [self triggerDBFailure:DBFailure_LibraryCriticalError];
    }
}

- (void)triggerDBFailure:(DBFailureKind)dbFailureKind {
    switch(dbFailureKind) {
        case DBFailure_NonCriticalDataNotFound:
            SM_LOG_ERROR(@"Database '%@': some data not found, considering DB consisteny not compromised. Application will continue working normally.", _dbFilePath);
            break;

        case DBFailure_CriticalDataNotFound:
            _dbInvalid = YES;
            _dbMustBeReset = YES;

            // TODO: Propagate this to the user via a dialog message
            SM_LOG_ERROR(@"Database '%@': critical data not found, consider DB consistency violated. Database will be dropped.", _dbFilePath);
            break;
            
        case DBFailure_LibraryCriticalError:
            _dbInvalid = YES;
            _dbMustBeReset = YES;
            
            // TODO: Propagate this to the user via a dialog message
            SM_LOG_ERROR(@"Database '%@': library function has failed, consider DB consistency violated. Database will be dropped.", _dbFilePath);
            break;

        case DBFailure_Busy:
            _dbInvalid = YES;
            
            // TODO: Propagate this to the user via a dialog message
            SM_LOG_ERROR(@"Database '%@': DB is blocked by an external process. Database will not be used or saved until application is restarted.", _dbFilePath);
            break;

        case DBFailure_WriteError:
            _dbInvalid = YES;

            // TODO: Propagate this to the user via a dialog message
            SM_LOG_ERROR(@"Database '%@': disk error. Database will not be used until application is restarted.", _dbFilePath);
            break;
    }
}

- (sqlite3*)openDatabaseInternal:(NSString*)filename {
    sqlite3 *database = nil;
    
    const int openDatabaseResult = sqlite3_open(filename.UTF8String, &database);
    if(openDatabaseResult == SQLITE_OK) {
        SM_LOG_NOISE(@"Database %@ open successfully", filename);
        return database;
    }
    else {
        SM_LOG_FATAL(@"Database %@ cannot be open", filename);
        return nil;
    }
}

- (sqlite3*)openDatabase:(DBOpenMode)openMode {
    if(_dbMustBeReset) {
        // A previous database operation has failed; the DB is inconsistent.
        // So just drop and re-initialize it.
        [self resetDatabase:_dbFilePath];
        
        // Do not use the database afterwards, as it should be re-initialized
        // with the full application data on startup.
        _dbInvalid = YES;
        return nil;
    }
    
    if(_dbInvalid) {
        // Database is invalid, so just drop every operation.
        return nil;
    }
    
    if(openMode == DBOpenMode_ReadWrite) {
        if([self shouldStartReclaimingOldData]) {
            [self reclaimOldData];
        }
    }
    
    return [self openDatabaseInternal:_dbFilePath];
}

- (uint64_t)dbFileSize {
    const uint64_t fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:_dbFilePath error:nil] fileSize];

    SM_LOG_DEBUG(@"Database file '%@' size is %llu bytes", _dbFilePath, fileSize);
    
    return fileSize;
}

- (BOOL)shouldStartReclaimingOldData {
    const uint64_t fileSizeMb = [self dbFileSize] / (1024 * 1024);

    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    NSUInteger maxStorageSizeMb = [appDelegate preferencesController].localStorageSizeMb;
    
    if(maxStorageSizeMb != 0 && fileSizeMb >= maxStorageSizeMb) {
        SM_LOG_INFO(@"Database file '%@' size is %llu bytes, which exceeds the max database size (%lu bytes)", _dbFilePath, fileSizeMb, maxStorageSizeMb);
        return YES;
    }
    
    return NO;
}

- (BOOL)shouldReclaimMoreOldData {
    const uint64_t fileSizeMb = [self dbFileSize] / (1024 * 1024);

    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    NSUInteger maxStorageSizeMb = [appDelegate preferencesController].localStorageSizeMb;
    NSUInteger sizeToReclaimMb = maxStorageSizeMb / 5;
    
    if(fileSizeMb > maxStorageSizeMb - sizeToReclaimMb) {
        SM_LOG_INFO(@"Database file '%@' size is %llu mb, which still exceeds the reasonable database size (%lu mb)", _dbFilePath, fileSizeMb, maxStorageSizeMb);
        
        return YES;
    }
    
    return NO;
}

- (void)reclaimMessageBodies:(NSMutableOrderedSet*)folderBodiesCounts {
    NSDate *timeBefore = [NSDate date];
    const uint64_t fileSizeBefore = [self dbFileSize];
    
    SM_LOG_INFO(@"Database '%@' reclamation is starting, file size %llu", _dbFilePath, fileSizeBefore);
    
    NSAssert(folderBodiesCounts.count > 0, @"no folders with counts");

    NSUInteger bodiedCountReclaimed = 0, headersCountReclaimed = 0;
    
    BOOL dbQueryFailed = NO;
    
    do {
        dbQueryFailed = NO;
        
        [folderBodiesCounts sortUsingComparator:^NSComparisonResult(id a, id b) {
            FolderWithCounts *f1 = (FolderWithCounts*)a;
            FolderWithCounts *f2 = (FolderWithCounts*)b;
            
            const NSUInteger c1 = f1.bodiesCount + f1.headersCount / HEADERS_BODIES_RECLAIM_RATIO;
            const NSUInteger c2 = f2.bodiesCount + f2.headersCount / HEADERS_BODIES_RECLAIM_RATIO;

            if(c1 < c2) {
                return NSOrderedAscending;
            }
            else if(c1 > c2) {
                return NSOrderedDescending;
            }
            else {
                return NSOrderedSame;
            }
        }];
        
        FolderWithCounts *folderDesc = [folderBodiesCounts lastObject];
        NSAssert(folderDesc != nil, @"folder not found");
        
        if(folderDesc.headersCount == 0 && folderDesc.bodiesCount == 0) {
            SM_LOG_WARNING(@"No more message bodies and headres in the database to reclaim!");
            break;
        }
        
        sqlite3 *database = [self openDatabaseInternal:_dbFilePath];
        if(database == nil) {
            SM_LOG_ERROR(@"could not open database");
            
            dbQueryFailed = YES;
            break;
        }
        
        // Choose what to reclaim: headers or bodies from this folder.
        if(folderDesc.bodiesCount >= folderDesc.headersCount / HEADERS_BODIES_RECLAIM_RATIO) {
            // Case 1: there are too many bodies, that is, too many old messages have its bodies stored.
            //         So we reclaim these old bodies, leaving bodyless headers alone.
            do {
                const NSUInteger bodiesCountToDelete = (folderDesc.bodiesCount >= BODIES_COUNT_RECLAIM_STEP? BODIES_COUNT_RECLAIM_STEP : folderDesc.bodiesCount);
                NSAssert(bodiesCountToDelete > 0, @"no bodies to delete");
                
                SM_LOG_INFO(@"Reclaiming %lu message bodies from folder %lu, which has %lu headers and %lu bodies", bodiesCountToDelete, folderDesc.folderId, folderDesc.headersCount, folderDesc.bodiesCount);
                
                NSString *deleteMessageBodiesSql = [NSString stringWithFormat:@"DELETE FROM MESSAGEBODIES%lu WHERE TIMESTAMP IN (SELECT TIMESTAMP FROM MESSAGEBODIES%lu ORDER BY TIMESTAMP ASC LIMIT %lu)", folderDesc.folderId, folderDesc.folderId, bodiesCountToDelete];
                
                sqlite3_stmt *statement = NULL;
                const int sqlPrepareResult = sqlite3_prepare_v2(database, deleteMessageBodiesSql.UTF8String, -1, &statement, NULL);
                
                if(sqlPrepareResult == SQLITE_OK) {
                    const int sqlStepResult = sqlite3_step(statement);

                    const int sqlFinalizeResult = sqlite3_finalize(statement);
                    SM_LOG_NOISE(@"finalize folders bodies delete statement result %d", sqlFinalizeResult);
                    
                    if(sqlStepResult != SQLITE_DONE) {
                        SM_LOG_ERROR(@"Failed to execute bodies delete statement for folder id %lu, error %d", folderDesc.folderId, sqlPrepareResult);

                        [self triggerDBFailureWithSQLiteError:sqlStepResult];

                        dbQueryFailed = YES;
                        break;
                    }
                    
                    //
                    // TODO: Remove the reclaimed messages UIDs from _messagesWithBodies.
                    //
                    
                    NSAssert(folderDesc.bodiesCount >= bodiesCountToDelete, @"folderDesc.bodiesCount %lu < bodiesCountToDelete %lu", folderDesc.bodiesCount, bodiesCountToDelete);
                    
                    folderDesc.bodiesCount -= bodiesCountToDelete;
                    bodiedCountReclaimed += bodiesCountToDelete;
                }
                else {
                    SM_LOG_ERROR(@"Failed to prepare bodies delete statement for folder id %lu, error %d", folderDesc.folderId, sqlPrepareResult);
                    
                    [self triggerDBFailureWithSQLiteError:sqlPrepareResult];
                    
                    dbQueryFailed = YES;
                    break;
                }
            } while(FALSE);
        }
        else {
            // Case 2: there so many headers, that for very few of them there is a body stored.
            //         So just wipe out empty headers.
            
            // TODO: Implement elaboration: no point to wipe out headers for which there _is_ a body
            //       stored in the DB. That is, simple logic "just remove oldest headers" is too simple.
            //       So for every header pre-selected to be removed we should check whether it is bodyless.
            
            do {
                const NSUInteger headersCountToDelete = (folderDesc.headersCount >= HEADERS_COUNT_RECLAIM_STEP? HEADERS_COUNT_RECLAIM_STEP : folderDesc.headersCount);
                NSAssert(headersCountToDelete > 0, @"no headers to delete");
                
                SM_LOG_INFO(@"Reclaiming %lu message headers from folder %lu, which has %lu headers and %lu bodies", headersCountToDelete, folderDesc.folderId, folderDesc.headersCount, folderDesc.bodiesCount);
                
                NSString *deleteMessageHeadersSql = [NSString stringWithFormat:@"DELETE FROM FOLDER%lu WHERE TIMESTAMP IN (SELECT TIMESTAMP FROM FOLDER%lu ORDER BY TIMESTAMP ASC LIMIT %lu)", folderDesc.folderId, folderDesc.folderId, headersCountToDelete];
                
                sqlite3_stmt *statement = NULL;
                const int sqlPrepareResult = sqlite3_prepare_v2(database, deleteMessageHeadersSql.UTF8String, -1, &statement, NULL);
                
                if(sqlPrepareResult == SQLITE_OK) {
                    const int sqlStepResult = sqlite3_step(statement);
                    
                    const int sqlFinalizeResult = sqlite3_finalize(statement);
                    SM_LOG_NOISE(@"finalize folders headers delete statement result %d", sqlFinalizeResult);
                    
                    if(sqlStepResult != SQLITE_DONE) {
                        SM_LOG_ERROR(@"Failed to execute headers delete statement for folder id %lu, error %d", folderDesc.folderId, sqlPrepareResult);
                        
                        [self triggerDBFailureWithSQLiteError:sqlStepResult];
                        
                        dbQueryFailed = YES;
                        break;
                    }
                    
                    NSAssert(folderDesc.headersCount >= headersCountToDelete, @"folderDesc.headersCount %lu < headersCountToDelete %lu", folderDesc.headersCount, headersCountToDelete);
                    
                    folderDesc.headersCount -= headersCountToDelete;
                    headersCountReclaimed += headersCountToDelete;
                }
                else {
                    SM_LOG_ERROR(@"Failed to prepare headers delete statement for folder id %lu, error %d", folderDesc.folderId, sqlPrepareResult);
                    
                    [self triggerDBFailureWithSQLiteError:sqlPrepareResult];
                    
                    dbQueryFailed = YES;
                    break;
                }
            } while(FALSE);
        }
        
        if(!dbQueryFailed) {
            const char *vacuumStmt = "VACUUM";
            const int sqlVacuumResult = sqlite3_exec(database, vacuumStmt, NULL, NULL, NULL);
            if(sqlVacuumResult == SQLITE_OK) {
                SM_LOG_DEBUG(@"Database cleanup successful");
            }
            else {
                SM_LOG_ERROR(@"Database cleanup failed, error %d", sqlVacuumResult);

                [self triggerDBFailureWithSQLiteError:sqlVacuumResult];

                dbQueryFailed = YES;
            }
        }
        
        [self closeDatabase:database];
        
        if(dbQueryFailed) {
            SM_LOG_ERROR(@"Database query failed");
            break;
        }
    } while([self shouldReclaimMoreOldData]);

    NSDate *timeAfter = [NSDate date];
    const uint64_t fileSizeAfter = [self dbFileSize];

    SM_LOG_INFO(@"Database '%@' reclamation %@, reclaimed %lu message bodies (total %llu bytes), current file size %llu. Total %f ms spent.", _dbFilePath, (dbQueryFailed? @"failed" : @"completed"), bodiedCountReclaimed, fileSizeBefore - fileSizeAfter, fileSizeAfter, [timeAfter timeIntervalSinceDate:timeBefore]);
}

- (NSNumber*)getHeadersCountNoChecks:(sqlite3*)database folderId:(NSNumber*)folderId {
    NSString *folderName = [_folderNames objectForKey:folderId];
    NSString *getCountSql = [NSString stringWithFormat:@"SELECT COUNT(*) FROM FOLDER%@", folderId];
    
    sqlite3_stmt *statement = NULL;
    const int sqlPrepareResult = sqlite3_prepare_v2(database, getCountSql.UTF8String, -1, &statement, NULL);
    if(sqlPrepareResult != SQLITE_OK) {
        SM_LOG_ERROR(@"could not prepare messages headers count statement, error %d", sqlPrepareResult);
        return nil;
    }
    
    NSNumber *headersCountResult = nil;
    
    do {
        const int sqlStepResult = sqlite3_step(statement);
        
        if(sqlStepResult != SQLITE_ROW) {
            SM_LOG_ERROR(@"Failed to get message headers count from folder %@, error %d", folderName, sqlStepResult);
            break;
        }
        
        NSUInteger headersCount = sqlite3_column_int(statement, 0);
        SM_LOG_DEBUG(@"Headers count in folder %@ is %lu", folderName, headersCount);
        
        headersCountResult = [NSNumber numberWithUnsignedInteger:headersCount];
    } while(FALSE);
    
    const int sqlFinalizeResult = sqlite3_finalize(statement);
    SM_LOG_NOISE(@"finalize message headers count statement result %d", sqlFinalizeResult);
    
    return headersCountResult;
}

- (NSNumber*)getBodiesCountNoChecks:(sqlite3*)database folderId:(NSNumber*)folderId {
    NSString *folderName = [_folderNames objectForKey:folderId];
    NSString *getCountSql = [NSString stringWithFormat:@"SELECT COUNT(*) FROM MESSAGEBODIES%@", folderId];
    
    sqlite3_stmt *statement = NULL;
    const int sqlPrepareResult = sqlite3_prepare_v2(database, getCountSql.UTF8String, -1, &statement, NULL);
    if(sqlPrepareResult != SQLITE_OK) {
        SM_LOG_ERROR(@"could not prepare messages bodies count statement, error %d", sqlPrepareResult);
        return nil;
    }
    
    NSNumber *bodiesCountResult = nil;
    
    do {
        const int sqlStepResult = sqlite3_step(statement);
        
        if(sqlStepResult != SQLITE_ROW) {
            SM_LOG_ERROR(@"Failed to get message bodies count from folder %@, error %d", folderName, sqlStepResult);
            break;
        }
        
        NSUInteger bodiesCount = sqlite3_column_int(statement, 0);
        SM_LOG_DEBUG(@"Bodies count in folder %@ is %lu", folderName, bodiesCount);
        
        bodiesCountResult = [NSNumber numberWithUnsignedInteger:bodiesCount];
    } while(FALSE);
    
    const int sqlFinalizeResult = sqlite3_finalize(statement);
    SM_LOG_NOISE(@"finalize message bodies count statement result %d", sqlFinalizeResult);

    return bodiesCountResult;
}

- (void)reclaimOldData {
    //
    // The primary target for reclamation is message bodies.
    // So we reclaim as many bodies as it seems reasonable not to kill the user data at all.
    // The idea is to balance between message headers and message bodies.
    // It seems reasonable to keep the ratio bodies/headers between [0.1, 1.0]. That is, in the
    // worst case, just 1 body per 10 messages. If the ration goes down from that, start
    // reclaiming headers.
    //
    // 1) Collect the counts across all MESSAGES and MESSAGEBODIES tables.
    // 2) Pick the fattest pair:
    //    - use absolute number of bodies and headers;
    //    - if another table has similar counts, pick the one with larger bodies/headers ratio;
    // 3) Reclaim bodies with smallest TIMESTAMP first; use bulk deletion.
    // 4) Check the file size; if it's less than ('size limit' - 'size to reclaim'), stop.
    // 5) Otherwise, repeat from step 2.
    //
    NSMutableOrderedSet *folderBodiesCounts = [[NSMutableOrderedSet alloc] init];
    
    sqlite3 *database = [self openDatabaseInternal:_dbFilePath];
    if(database == nil) {
        SM_LOG_ERROR(@"could not open database");
        return;
    }
    
    BOOL dbQueryFailed = NO;

    for(NSNumber *folderId in _folderNames) {
        NSString *folderName = [_folderNames objectForKey:folderId];
        NSNumber *headersCount = [self getHeadersCountNoChecks:database folderId:folderId];
        NSNumber *bodiesCount = [self getBodiesCountNoChecks:database folderId:folderId];

        if(headersCount != nil || bodiesCount != nil) {
            [folderBodiesCounts addObject:[[FolderWithCounts alloc] initWithFolderId:[folderId unsignedIntegerValue] headersCount:(headersCount != nil? [headersCount unsignedIntegerValue] : 0) bodiesCount:(bodiesCount != nil? [bodiesCount unsignedIntegerValue] : 0)]];
        }
        else {
            SM_LOG_ERROR(@"could not get headers and bodies counts from folder '%@'", folderName);
        }
    }
    
    [self closeDatabase:database];
    
    if(!dbQueryFailed) {
        SM_LOG_INFO(@"Starting database data reclamation");

        [self reclaimMessageBodies:folderBodiesCounts];
    }
    else {
        SM_LOG_ERROR(@"Database is inconsistent, data reclamation cannot start");
    }
}

- (void)closeDatabase:(sqlite3*)database {
    const int sqlCloseResult = sqlite3_close(database);
    
    if(sqlCloseResult != SQLITE_OK) {
        SM_LOG_ERROR(@"could not close database, error %d", sqlCloseResult);
    }
}

- (void)checkDatabase:(NSString*)dbFilename {
    BOOL databaseValid = NO;
    
    sqlite3 *const database = [self openDatabaseInternal:dbFilename];
    if(database != nil) {
        char *errMsg = NULL;
        const char *checkStmt = "PRAGMA QUICK_CHECK";
        
        const int sqlResult = sqlite3_exec(database, checkStmt, NULL, NULL, &errMsg);
        if(sqlResult == SQLITE_OK) {
            SM_LOG_DEBUG(@"Database '%@' check successful.", dbFilename);
            
            databaseValid = YES;
        }
        else {
            SM_LOG_ERROR(@"Database '%@' check failed: %s (error %d). Database will be erased and created from ground.", dbFilename, errMsg, sqlResult);
        }
        
        [self closeDatabase:database];
    }
    
    if(!databaseValid) {
        SM_LOG_ERROR(@"Database '%@' is inconsistent and will be reset.", dbFilename);
        
        [self resetDatabase:dbFilename];
    }
    else {
        SM_LOG_INFO(@"Database '%@' is consistent.", dbFilename);
    }
}

- (void)resetDatabase:(NSString*)dbFilename {
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:dbFilename error:&error];
    
    if(error != nil && error.code != NSFileNoSuchFileError) {
        SM_LOG_ERROR(@"Cannot remove database file '%@': %@", dbFilename, error);
        
        _dbInvalid = YES;
    }
    else {
        SM_LOG_INFO(@"Database '%@' has been erased as inconsistent.", dbFilename);
        
        _dbInvalid = NO;
    }
    
    _dbMustBeReset = NO;
}

- (void)initDatabase:(NSString*)dbFilename {
    BOOL initSuccessful = NO;
    
    sqlite3 *const database = [self openDatabaseInternal:dbFilename];
    
    if(database != nil) {
        do {
            if(![self createOpQueuesTable:database]) {
                SM_LOG_ERROR(@"Failed to init op queues table");
                break;
            }
            
            if(![self createFoldersTable:database]) {
                SM_LOG_ERROR(@"Failed to init folder table");
                break;
            }
            
            if(![self createMessageThreadsTable:database]) {
                SM_LOG_ERROR(@"Failed to init message thread table");
                break;
            }
            
            if(![self loadFolderIds:database]) {
                SM_LOG_ERROR(@"Failed to load folder ids");
                break;
            }
            
            SM_LOG_INFO(@"Database initialized successfully");
            
            initSuccessful = YES;
        } while(FALSE);
        
        [self closeDatabase:database];
    }
    else {
        SM_LOG_ERROR(@"Cannot open database file '%@'. Database will be reset.", dbFilename);
    }
    
    if(initSuccessful) {
        _dbInvalid = NO;
    }
    else {
        _dbInvalid = YES;
    }
}

- (BOOL)createOpQueuesTable:(sqlite3*)database {
    char *errMsg = NULL;
    const char *createStmt = "CREATE TABLE IF NOT EXISTS OPQUEUES (NAME TEXT UNIQUE, CONTENTS BLOB)";
    
    const int sqlResult = sqlite3_exec(database, createStmt, NULL, NULL, &errMsg);
    if(sqlResult != SQLITE_OK) {
        SM_LOG_ERROR(@"Failed to create table FOLDERS: %s, error %d", errMsg, sqlResult);
        return FALSE;
    }
    
    return TRUE;
}

- (BOOL)createMessageThreadsTable:(sqlite3*)database {
    char *errMsg = NULL;
    const char *createStmt = "CREATE TABLE IF NOT EXISTS MESSAGETHREADS (THREADID INTEGER, FOLDERID INTEGER, UIDARRAY BLOB)";
    
    const int sqlResult = sqlite3_exec(database, createStmt, NULL, NULL, &errMsg);
    if(sqlResult != SQLITE_OK) {
        SM_LOG_ERROR(@"Failed to create table FOLDERS: %s, error %d", errMsg, sqlResult);
        return FALSE;
    }
    
    return TRUE;
}

- (BOOL)createFoldersTable:(sqlite3*)database {
    char *errMsg = NULL;
    const char *createStmt = "CREATE TABLE IF NOT EXISTS FOLDERS (ID INTEGER PRIMARY KEY, NAME TEXT UNIQUE, DELIMITER INTEGER, FLAGS INTEGER)";
    
    const int sqlResult = sqlite3_exec(database, createStmt, NULL, NULL, &errMsg);
    if(sqlResult != SQLITE_OK) {
        SM_LOG_ERROR(@"Failed to create table FOLDERS: %s, error %d", errMsg, sqlResult);
        return FALSE;
    }
    
    return TRUE;
}

- (void)deleteOpQueueInternal:(NSString *)queueName database:(sqlite3*)database{
    NSString *removeSql = [NSString stringWithFormat:@"DELETE FROM OPQUEUES WHERE NAME = \"%@\"", queueName];
    const char *removeStmt = [removeSql UTF8String];
    
    sqlite3_stmt *statement = NULL;
    const int sqlPrepareResult = sqlite3_prepare_v2(database, removeStmt, -1, &statement, NULL);
    if(sqlPrepareResult != SQLITE_OK) {
        SM_LOG_ERROR(@"could not prepare folders remove statement, error %d", sqlPrepareResult);
        
        [self triggerDBFailureWithSQLiteError:sqlPrepareResult];
        
        return;
    }
    
    const int sqlResult = sqlite3_step(statement);
    
    const int sqlFinalizeResult = sqlite3_finalize(statement);
    SM_LOG_NOISE(@"finalize up queue statement result %d", sqlFinalizeResult);
    
    if(sqlResult == SQLITE_DONE) {
        SM_LOG_DEBUG(@"Op queue %@ successfully removed", queueName);
    }
    else {
        SM_LOG_ERROR(@"Failed to remove op queue %@, error %d", queueName, sqlResult);
        
        [self triggerDBFailureWithSQLiteError:sqlResult];
        
        return;
    }
}

- (void)saveOpQueue:(SMOperationQueue*)opQueue queueName:(NSString*)queueName {
    SM_LOG_INFO(@"scheduling save for op queue '%@', length %lu", queueName, opQueue.count);

    NSData *encodedOpQueue = [NSKeyedArchiver archivedDataWithRootObject:opQueue];
    NSAssert(encodedOpQueue != nil, @"could not encode op queue");

    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_NOISE(@"serial queue length increased: %d", serialQueueLen);
    
    dispatch_async(_serialQueue, ^{
        [self runUrgentTasks];
        
        sqlite3 *database = [self openDatabase:DBOpenMode_ReadWrite];
        
        if(database != nil) {
            do {
                [self deleteOpQueueInternal:queueName database:database];
                
                NSString *opQueueInsertSql = [NSString stringWithFormat:@"INSERT INTO OPQUEUES (\"NAME\", \"CONTENTS\") VALUES (?, ?)"];
                const char *opQueueInsertStmt = [opQueueInsertSql UTF8String];
                
                sqlite3_stmt *statement = NULL;
                const int sqlPrepareResult = sqlite3_prepare_v2(database, opQueueInsertStmt, -1, &statement, NULL);
                if(sqlPrepareResult != SQLITE_OK) {
                    SM_LOG_ERROR(@"could not prepare load statement, error %d", sqlPrepareResult);
                    
                    [self triggerDBFailureWithSQLiteError:sqlPrepareResult];
                    break;
                }
                
                BOOL dbQueryFailed = NO;
                int dbQueryError = SQLITE_OK;
                
                do {
                    int bindResult;
                    if((bindResult = sqlite3_bind_text(statement, 1, queueName.UTF8String, (int)queueName.length, SQLITE_STATIC)) != SQLITE_OK) {
                        SM_LOG_ERROR(@"op queue '%@', could not bind argument 1 (NAME), error %d", queueName, bindResult);
                        
                        dbQueryFailed = YES;
                        dbQueryError = bindResult;
                        break;
                    }
                    
                    if((bindResult = sqlite3_bind_blob(statement, 2, encodedOpQueue.bytes, (int)encodedOpQueue.length, SQLITE_STATIC)) != SQLITE_OK) {
                        SM_LOG_ERROR(@"op queue '%@', could not bind argument 2 (CONTENTS), error %d", queueName, bindResult);
                        
                        dbQueryFailed = YES;
                        dbQueryError = bindResult;
                        break;
                    }
                    
                    const int sqlStepResult = sqlite3_step(statement);
                    
                    if(sqlStepResult != SQLITE_DONE) {
                        SM_LOG_ERROR(@"Failed to insert op queue '%@', error %d", queueName, sqlStepResult);
                        
                        dbQueryFailed = YES;
                        dbQueryError = sqlStepResult;
                        break;
                    }
                } while(FALSE);
                
                const int sqlFinalizeResult = sqlite3_finalize(statement);
                SM_LOG_NOISE(@"finalize op queue insert statement result %d", sqlFinalizeResult);
                
                if(dbQueryFailed) {
                    SM_LOG_ERROR(@"SQL query has failed");
                    
                    [self triggerDBFailureWithSQLiteError:dbQueryError];
                    break;
                }
                
                SM_LOG_INFO(@"Op queue '%@' successfully saved to database", queueName);
            } while(FALSE);
            
            [self closeDatabase:database];
        }
        
        const int32_t newSerialQueueLen = OSAtomicAdd32(-1, &_serialQueueLength);
        SM_LOG_NOISE(@"serial queue length decreased: %d", newSerialQueueLen);
    });
}

- (void)deleteOpQueue:(NSString*)queueName {
    SM_LOG_INFO(@"deleting op queue '%@'", queueName);
    
    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_NOISE(@"serial queue length increased: %d", serialQueueLen);
    
    dispatch_async(_serialQueue, ^{
        [self runUrgentTasks];
        
        sqlite3 *database = [self openDatabase:DBOpenMode_ReadWrite];
        
        if(database != nil) {
            [self deleteOpQueueInternal:queueName database:database];
            [self closeDatabase:database];
        }
        
        const int32_t newSerialQueueLen = OSAtomicAdd32(-1, &_serialQueueLength);
        SM_LOG_NOISE(@"serial queue length decreased: %d", newSerialQueueLen);
    });
}

- (SMDatabaseOp*)loadOpQueue:(NSString*)queueName block:(void (^)(SMOperationQueue*))getQueueBlock {
    SM_LOG_INFO(@"scheduling load for op queue '%@'", queueName);

    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_NOISE(@"serial queue length increased: %d", serialQueueLen);
    
    SMDatabaseOp *dbOp = [[SMDatabaseOp alloc] init];
    
    dispatch_async(_serialQueue, ^{
        [self runUrgentTasks];
        
        if(dbOp.cancelled) {
            SM_LOG_DEBUG(@"DB op was cancelled");
            return;
        }
        
        SM_LOG_INFO(@"loading op queue '%@'", queueName);

        SMOperationQueue *opQueue = nil;

        sqlite3 *database = [self openDatabase:DBOpenMode_Read];
        
        if(database != nil) {
            do {
                BOOL dbQueryFailed = NO;
                int dbQueryError = SQLITE_OK;
                
                NSString *folderSelectSql = [NSString stringWithFormat:@"SELECT CONTENTS FROM OPQUEUES WHERE NAME = \"%@\"", queueName];
                const char *folderSelectStmt = [folderSelectSql UTF8String];
                
                sqlite3_stmt *statement = NULL;
                const int sqlSelectPrepareResult = sqlite3_prepare_v2(database, folderSelectStmt, -1, &statement, NULL);
                
                if(sqlSelectPrepareResult == SQLITE_OK) {
                    const int stepResult = sqlite3_step(statement);
                    if(stepResult == SQLITE_ROW) {
                        int dataSize = sqlite3_column_bytes(statement, 0);
                        NSData *queueData = [NSData dataWithBytesNoCopy:(void *)sqlite3_column_blob(statement, 0) length:dataSize freeWhenDone:NO];
                        
                        opQueue = [NSKeyedUnarchiver unarchiveObjectWithData:queueData];
                        if(opQueue == nil) {
                            SM_LOG_ERROR(@"could not decode op queue '%@'", queueName);
                            
                            dbQueryFailed = YES;
                        }
                        else {
                            SM_LOG_INFO(@"loaded op queue '%@', length %lu", queueName, opQueue.count);
                        }
                    }
                    else if(stepResult == SQLITE_DONE) {
                        SM_LOG_INFO(@"op queue '%@' not found", queueName);
                    }
                    else {
                        SM_LOG_ERROR(@"could not load op queue '%@', error %d", queueName, sqlSelectPrepareResult);
                        
                        dbQueryFailed = YES;
                        dbQueryError = stepResult;
                    }
                }
                else {
                    SM_LOG_ERROR(@"could not prepare select statement for op queue '%@', error %d", queueName, sqlSelectPrepareResult);
                    
                    dbQueryFailed = YES;
                    dbQueryError = sqlSelectPrepareResult;
                }
                
                const int sqlFinalizeResult = sqlite3_finalize(statement);
                SM_LOG_NOISE(@"finalize op load statement result %d", sqlFinalizeResult);
                
                if(dbQueryFailed) {
                    SM_LOG_ERROR(@"database query failed");
                    
                    if(dbQueryError != SQLITE_OK) {
                        [self triggerDBFailureWithSQLiteError:dbQueryError];
                    }
                    else {
                        [self triggerDBFailure:DBFailure_CriticalDataNotFound];
                    }
                    
                    break;
                }
            } while(FALSE);
            
            [self closeDatabase:database];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if(dbOp.cancelled) {
                SM_LOG_DEBUG(@"DB op was cancelled");
                return;
            }
            
            getQueueBlock(opQueue);
        });
        
        const int32_t newSerialQueueLen = OSAtomicAdd32(-1, &_serialQueueLength);
        SM_LOG_NOISE(@"serial queue length decreased: %d", newSerialQueueLen);
    });

    return dbOp;
}

- (NSDictionary*)loadDataFromDB:(sqlite3*)database query:(const char *)sqlQuery {
    NSAssert(database != nil, @"no database open");
    
    sqlite3_stmt *statement = NULL;
    const int sqlPrepareResult = sqlite3_prepare_v2(database, sqlQuery, -1, &statement, NULL);
    if(sqlPrepareResult != SQLITE_OK) {
        SM_LOG_ERROR(@"could not prepare load statement, error %d", sqlPrepareResult);
        return NULL;
    }
    
    NSMutableArray *arrRows = [[NSMutableArray alloc] init];
    NSMutableArray *arrColumnNames = [[NSMutableArray alloc] init];
    const int totalColumns = sqlite3_column_count(statement);
    
    while(true) {
        const int sqlStepResult = sqlite3_step(statement);
        if(sqlStepResult == SQLITE_DONE) {
            break;
        }
        else if(sqlStepResult != SQLITE_ROW) {
            SM_LOG_ERROR(@"sqlite step error %d", sqlStepResult);
            break;
        }
        
        NSMutableArray *arrDataRow = [[NSMutableArray alloc] init];
        
        for(int i = 0; i < totalColumns; i++){
            char *dbDataAsChars = (char *)sqlite3_column_text(statement, i);
            
            if(dbDataAsChars != NULL) {
                [arrDataRow addObject:[NSString stringWithUTF8String:dbDataAsChars]];
            }
            
            if(arrColumnNames.count != totalColumns) {
                dbDataAsChars = (char *)sqlite3_column_name(statement, i);
                [arrColumnNames addObject:[NSString stringWithUTF8String:dbDataAsChars]];
            }
        }
        
        if(arrDataRow.count > 0) {
            [arrRows addObject:arrDataRow];
        }
    }
    
    const int sqlFinalizeResult = sqlite3_finalize(statement);
    SM_LOG_NOISE(@"finalize folders insert statement result %d", sqlFinalizeResult);
    
    NSDictionary *results = [[NSMutableDictionary alloc] init];
    
    [results setValue:arrColumnNames forKey:@"Columns"];
    [results setValue:arrRows forKey:@"Rows"];
    
    return results;
}

- (BOOL)loadFolderIds:(sqlite3*)database {
    NSMutableDictionary *folderIds = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *folderNames = [[NSMutableDictionary alloc] init];
    
    const char *sqlQuery = "SELECT * FROM FOLDERS";
    NSDictionary *foldersTable = [self loadDataFromDB:database query:sqlQuery];
    if(foldersTable == NULL) {
        SM_LOG_ERROR(@"Could not load folders from the database.");
        return FALSE;
    }
    
    NSArray *columns = [foldersTable objectForKey:@"Columns"];
    NSArray *rows = [foldersTable objectForKey:@"Rows"];
    
    const NSInteger idColumn = [columns indexOfObject:@"ID"];
    const NSInteger nameColumn = [columns indexOfObject:@"NAME"];
    
    if(idColumn != NSNotFound && nameColumn != NSNotFound) {
        for(NSUInteger i = 0; i < rows.count; i++) {
            NSArray *row = rows[i];
            NSString *idStr = row[idColumn];
            NSString *nameStr = row[nameColumn];
            NSNumber *folderId = [NSNumber numberWithUnsignedInteger:[idStr integerValue]];
            
            [folderIds setObject:folderId forKey:nameStr];
            [folderNames setObject:nameStr forKey:folderId];
            
            if(![self loadMessageBodiesInfo:database folderId:folderId]) {
                SM_LOG_ERROR(@"Could not load folder \"%@\" from the database", nameStr);
                return FALSE;
            }
            
            SM_LOG_DEBUG(@"Folder \"%@\" id %@", nameStr, folderId);
        }
    }
    
    _folderIds = folderIds;
    _folderNames = folderNames;
    
    return TRUE;
}

- (BOOL)loadMessageBodiesInfo:(sqlite3*)database folderId:(NSNumber*)folderId {
    BOOL error = NO;
    
    NSMutableSet *uidSet = [NSMutableSet set];
    
    NSString *getMessageBodySql = [NSString stringWithFormat:@"SELECT UID FROM MESSAGEBODIES%@", folderId];
    
    sqlite3_stmt *statement = NULL;
    const int sqlPrepareResult = sqlite3_prepare_v2(database, [getMessageBodySql UTF8String], -1, &statement, NULL);
    
    if(sqlPrepareResult == SQLITE_OK) {
        while(true) {
            const int sqlStepResult = sqlite3_step(statement);
            if(sqlStepResult == SQLITE_DONE) {
                break;
            }
            else if(sqlStepResult != SQLITE_ROW) {
                SM_LOG_ERROR(@"sqlite step error %d", sqlStepResult);
                
                error = YES;
                break;
            }
            
            uint32_t uid = sqlite3_column_int(statement, 0);
            
            SM_LOG_DEBUG(@"message with UID %u has its body in the database", uid);
            
            [uidSet addObject:[NSNumber numberWithUnsignedInt:uid]];
        }
    }
    else {
        SM_LOG_ERROR(@"could not prepare load statement, error %d", sqlPrepareResult);
        error = YES;
    }
    
    const int sqlFinalizeResult = sqlite3_finalize(statement);
    SM_LOG_NOISE(@"finalize message count statement result %d", sqlFinalizeResult);
    
    if(!error) {
        [_messagesWithBodies setObject:uidSet forKey:folderId];
    }
    
    return (error? FALSE : TRUE);
}

- (int)generateFolderId {
    while([_folderNames objectForKey:[NSNumber numberWithInt:_nextFolderId]] != nil) {
        _nextFolderId++;
        
        if(_nextFolderId < 0) {
            SM_LOG_WARNING(@"folderId overflow!");
            _nextFolderId = 0;
        }
    }
    
    return _nextFolderId++;
}

- (void)addDBFolder:(NSString*)folderName delimiter:(char)delimiter flags:(MCOIMAPFolderFlag)flags {
    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_NOISE(@"serial queue length increased: %d", serialQueueLen);
    
    dispatch_async(_serialQueue, ^{
        [self runUrgentTasks];
        
        NSNumber *folderId = [_folderIds objectForKey:folderName];
        if(folderId != nil) {
            SM_LOG_DEBUG(@"Folder %@ already exists (id %@)", folderName, folderId);
        }
        else {
            const int generatedFolderId = [self generateFolderId];
            NSNumber *folderId = [NSNumber numberWithInt:generatedFolderId];
            
            [_folderIds setObject:folderId forKey:folderName];
            [_folderNames setObject:folderName forKey:folderId];
            
            sqlite3 *database = [self openDatabase:DBOpenMode_ReadWrite];
            
            if(database != nil) {
                do {
                    //
                    // Step 1: Add the folder into the DB.
                    //
                    {
                        NSString *insertSql = [NSString stringWithFormat:@"INSERT INTO FOLDERS (ID, NAME, DELIMITER, FLAGS) VALUES (%@, \"%@\", %ld, %ld)", folderId, folderName, (NSInteger)delimiter, (NSInteger)flags];
                        const char *insertStmt = [insertSql UTF8String];
                        
                        sqlite3_stmt *statement = NULL;
                        const int sqlPrepareResult = sqlite3_prepare_v2(database, insertStmt, -1, &statement, NULL);
                        if(sqlPrepareResult != SQLITE_OK) {
                            SM_LOG_ERROR(@"could not prepare folders insert statement, error %d", sqlPrepareResult);
                            
                            [self triggerDBFailureWithSQLiteError:sqlPrepareResult];
                            break;
                        }
                        
                        BOOL dbQueryFailed = NO;
                        int dbQueryError = SQLITE_OK;
                        
                        do {
                            const int sqlResult = sqlite3_step(statement);

                            if(sqlResult == SQLITE_DONE) {
                                SM_LOG_DEBUG(@"Folder %@ successfully inserted", folderName);
                            }
                            else if(sqlResult == SQLITE_CONSTRAINT) {
                                SM_LOG_WARNING(@"Folder %@ already exists", folderName);
                            }
                            else {
                                SM_LOG_ERROR(@"Failed to insert folder %@, error %d", folderName, sqlResult);
                            
                                dbQueryError = sqlResult;
                                dbQueryFailed = YES;
                                break;
                            }
                        } while(FALSE);
                        
                        const int sqlFinalizeResult = sqlite3_finalize(statement);
                        SM_LOG_NOISE(@"finalize folders insert statement result %d", sqlFinalizeResult);

                        if(dbQueryFailed) {
                            SM_LOG_ERROR(@"database query failed");
                            
                            [self triggerDBFailureWithSQLiteError:dbQueryError];
                            break;
                        }
                    }
                
                    //
                    // Step 2: Create a unique folder table containing message UIDs.
                    //
                    {
                        NSString *createMessageTableSql = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS FOLDER%@ (UID INTEGER PRIMARY KEY UNIQUE, TIMESTAMP INTEGER, MESSAGE BLOB)", folderId];
                        const char *createMessageTableStmt = [createMessageTableSql UTF8String];
                        
                        char *errMsg = NULL;
                        const int sqlResult = sqlite3_exec(database, createMessageTableStmt, NULL, NULL, &errMsg);
                        if(sqlResult != SQLITE_OK) {
                            SM_LOG_ERROR(@"Failed to create table for folder id %@: %s, error %d", folderId, errMsg, sqlResult);

                            [self triggerDBFailureWithSQLiteError:sqlResult];
                            break;
                        }
                    }
                    
                    //
                    // Step 2: Create a unique folder table containing message bodies.
                    //
                    {
                        NSString *createBodiesTableSql = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS MESSAGEBODIES%@ (UID INTEGER PRIMARY KEY UNIQUE, TIMESTAMP INTEGER, MESSAGEBODY BLOB)", folderId];
                        const char *createStmt = [createBodiesTableSql UTF8String];
                        
                        const int sqlResult = sqlite3_exec(database, createStmt, NULL, NULL, NULL);
                        if(sqlResult != SQLITE_OK) {
                            SM_LOG_ERROR(@"Failed to create table MESSAGEBODIES%@: error %d", folderId, sqlResult);

                            [self triggerDBFailureWithSQLiteError:sqlResult];
                            break;
                        }
                    }
                    
                    //
                    // Step 3: Create another unique folder table containing plain message text: bodies, subjects, contacts.
                    //
                    {
                        NSString *createTextTableSql = [NSString stringWithFormat:@"CREATE VIRTUAL TABLE IF NOT EXISTS MESSAGETEXT%@ USING FTS4 (FROM, TO, CC, SUBJECT, MESSAGEBODY)", folderId];
                        const char *createStmt = [createTextTableSql UTF8String];
                        
                        const int sqlResult = sqlite3_exec(database, createStmt, NULL, NULL, NULL);
                        if(sqlResult != SQLITE_OK) {
                            SM_LOG_ERROR(@"Failed to create table MESSAGETEXT%@: error %d", folderId, sqlResult);
                            
                            [self triggerDBFailureWithSQLiteError:sqlResult];
                            break;
                        }
                    }
                    
                    //
                    // Finally, just store information about what messages have their bodies in the DB.
                    //
                    
                    [_messagesWithBodies setObject:[NSMutableSet set] forKey:folderId];
                } while(FALSE);
                
                [self closeDatabase:database];
            }
        }
        
        const int32_t newSerialQueueLen = OSAtomicAdd32(-1, &_serialQueueLength);
        SM_LOG_NOISE(@"serial queue length decreased: %d", newSerialQueueLen);
    });
}

- (void)renameDBFolder:(NSString*)folderName newName:(NSString*)newName {
    NSAssert(nil, @"TODO");
}

- (void)removeDBFolder:(NSString*)folderName {
    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_NOISE(@"serial queue length increased: %d", serialQueueLen);
    
    dispatch_async(_serialQueue, ^{
        [self runUrgentTasks];
        
        NSNumber *folderId = [_folderIds objectForKey:folderName];
        if(folderId == nil) {
            SM_LOG_ERROR(@"Folder %@ does not exist", folderName);
        }
        else {
            [_folderIds removeObjectForKey:folderId];
            [_folderNames removeObjectForKey:folderId];
            
            sqlite3 *database = [self openDatabase:DBOpenMode_ReadWrite];
            
            if(database != nil) {
                do {
                    {
                        NSString *removeSql = [NSString stringWithFormat:@"DELETE FROM FOLDERS WHERE NAME = \"%@\"", folderName];
                        const char *removeStmt = [removeSql UTF8String];
                        
                        sqlite3_stmt *statement = NULL;
                        const int sqlPrepareResult = sqlite3_prepare_v2(database, removeStmt, -1, &statement, NULL);
                        if(sqlPrepareResult != SQLITE_OK) {
                            SM_LOG_ERROR(@"could not prepare folders remove statement, error %d", sqlPrepareResult);
                            
                            [self triggerDBFailureWithSQLiteError:sqlPrepareResult];
                            break;
                        }
                        
                        const int sqlResult = sqlite3_step(statement);

                        const int sqlFinalizeResult = sqlite3_finalize(statement);
                        SM_LOG_NOISE(@"finalize folders remove statement result %d", sqlFinalizeResult);
                        
                        if(sqlResult == SQLITE_DONE) {
                            SM_LOG_INFO(@"Folder %@ successfully removed", folderName);
                        }
                        else {
                            SM_LOG_ERROR(@"Failed to remove folder %@, error %d", folderName, sqlResult);
                            
                            [self triggerDBFailureWithSQLiteError:sqlResult];
                            break;
                        }
                    }
                    
                    {
                        NSString *dropStmt = [NSString stringWithFormat:@"DROP TABLE FOLDER%@", folderId];
                        const int dropStmtResult = sqlite3_exec(database, dropStmt.UTF8String, NULL, NULL, NULL);
                        if(dropStmtResult == SQLITE_OK) {
                            SM_LOG_DEBUG(@"Folder %@ (id %@) table drop successful", folderName, folderId);
                        }
                        else {
                            SM_LOG_ERROR(@"Folder %@ (id %@) table drop failed (error %d)", folderName, folderId, dropStmtResult);
                            break;
                        }
                    }
                    
                    {
                        NSString *dropStmt = [NSString stringWithFormat:@"DROP TABLE MESSAGEBODIES%@", folderId];
                        const int dropStmtResult = sqlite3_exec(database, dropStmt.UTF8String, NULL, NULL, NULL);
                        if(dropStmtResult == SQLITE_OK) {
                            SM_LOG_DEBUG(@"Message bodies for folder %@ (id %@) table drop successful", folderName, folderId);
                        }
                        else {
                            SM_LOG_ERROR(@"Message bodies for folder %@ (id %@) table drop failed (error %d)", folderName, folderId, dropStmtResult);
                            break;
                        }
                    }

                    {
                        NSString *dropStmt = [NSString stringWithFormat:@"DROP TABLE MESSAGETEXT%@", folderId];
                        const int dropStmtResult = sqlite3_exec(database, dropStmt.UTF8String, NULL, NULL, NULL);
                        if(dropStmtResult == SQLITE_OK) {
                            SM_LOG_DEBUG(@"Message text for folder %@ (id %@) table drop successful", folderName, folderId);
                        }
                        else {
                            SM_LOG_ERROR(@"Message text for folder %@ (id %@) table drop failed (error %d)", folderName, folderId, dropStmtResult);
                            break;
                        }
                    }
                } while(FALSE);
            }
            
            [self closeDatabase:database];
        }
        
        const int32_t newSerialQueueLen = OSAtomicAdd32(-1, &_serialQueueLength);
        SM_LOG_NOISE(@"serial queue length decreased: %d", newSerialQueueLen);
    });
}

- (SMDatabaseOp*)loadDBFolders:(void (^)(NSArray*))loadFoldersBlock {
    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_NOISE(@"serial queue length increased: %d", serialQueueLen);
    
    SMDatabaseOp *dbOp = [[SMDatabaseOp alloc] init];
    
    dispatch_async(_serialQueue, ^{
        [self runUrgentTasks];
        
        if(dbOp.cancelled) {
            SM_LOG_DEBUG(@"DB op was cancelled");
            return;
        }
        
        NSMutableArray *folders = nil;
        
        sqlite3 *database = [self openDatabase:DBOpenMode_Read];
        
        if(database != nil) {
            const char *sqlQuery = "SELECT * FROM FOLDERS";
            NSDictionary *foldersTable = [self loadDataFromDB:database query:sqlQuery];
            NSArray *columns = [foldersTable objectForKey:@"Columns"];
            NSArray *rows = [foldersTable objectForKey:@"Rows"];
            
            const NSInteger nameColumn = [columns indexOfObject:@"NAME"];
            const NSInteger delimiterColumn = [columns indexOfObject:@"DELIMITER"];
            const NSInteger flagsColumn = [columns indexOfObject:@"FLAGS"];
            
            if(nameColumn == NSNotFound || delimiterColumn == NSNotFound || flagsColumn == NSNotFound) {
                if(columns.count > 0 && rows.count > 0) {
                    SM_LOG_ERROR(@"database corrupted: folder name/delimiter/flags columns not found: %ld/%ld/%ld", nameColumn, delimiterColumn, flagsColumn);
                    
                    [self triggerDBFailure:DBFailure_CriticalDataNotFound];
                }
            }
            else {
                folders = [NSMutableArray arrayWithCapacity:rows.count];
                
                for(NSUInteger i = 0; i < rows.count; i++) {
                    NSArray *row = rows[i];
                    NSString *name = row[nameColumn];
                    char delimiter = [((NSString*)row[delimiterColumn]) integerValue];
                    MCOIMAPFolderFlag flags = [((NSString*)row[flagsColumn]) integerValue];
                    
                    folders[i] = [[SMFolderDesc alloc] initWithFolderName:name delimiter:delimiter flags:flags];
                }
            }
            
            [self closeDatabase:database];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if(dbOp.cancelled) {
                SM_LOG_DEBUG(@"DB op was cancelled");
                return;
            }
            
            loadFoldersBlock(folders);
        });
        
        const int32_t newSerialQueueLen = OSAtomicAdd32(-1, &_serialQueueLength);
        SM_LOG_NOISE(@"serial queue length decreased: %d", newSerialQueueLen);
    });
    
    return dbOp;
}

- (SMDatabaseOp*)getMessagesCountInDBFolder:(NSString*)folderName block:(void (^)(NSUInteger))getMessagesCountBlock {
    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_NOISE(@"serial queue length increased: %d", serialQueueLen);
    
    SMDatabaseOp *dbOp = [[SMDatabaseOp alloc] init];
    
    dispatch_async(_serialQueue, ^{
        [self runUrgentTasks];
        
        if(dbOp.cancelled) {
            SM_LOG_DEBUG(@"DB op was cancelled");
            return;
        }
        
        NSUInteger messagesCount = 0;
        
        sqlite3 *database = [self openDatabase:DBOpenMode_Read];
        
        if(database != nil) {
            do {
                NSNumber *folderId = [_folderIds objectForKey:folderName];
                if(folderId != nil) {
                    NSString *getCountSql = [NSString stringWithFormat:@"SELECT COUNT(*) FROM FOLDER%@", folderId];
                    const char *getCountStmt = [getCountSql UTF8String];
                    
                    sqlite3_stmt *statement = NULL;
                    const int sqlPrepareResult = sqlite3_prepare_v2(database, getCountStmt, -1, &statement, NULL);
                    if(sqlPrepareResult != SQLITE_OK) {
                        SM_LOG_ERROR(@"could not prepare messages count statement, error %d", sqlPrepareResult);
                        
                        [self triggerDBFailureWithSQLiteError:sqlPrepareResult];
                        break;
                    }
                    
                    BOOL dbQueryFailed = NO;
                    int dbQueryError = SQLITE_OK;
                    
                    do {
                        const int sqlStepResult = sqlite3_step(statement);
                        
                        if(sqlStepResult != SQLITE_ROW) {
                            SM_LOG_ERROR(@"Failed to get messages count from folder %@, error %d", folderName, sqlStepResult);

                            dbQueryFailed = YES;
                            dbQueryError = sqlStepResult;
                            break;
                        }
                        
                        messagesCount = sqlite3_column_int(statement, 0);
                        
                        SM_LOG_DEBUG(@"Messages count in folder %@ is %lu", folderName, messagesCount);
                    } while(FALSE);
                    
                    const int sqlFinalizeResult = sqlite3_finalize(statement);
                    SM_LOG_NOISE(@"finalize message count statement result %d", sqlFinalizeResult);

                    if(dbQueryFailed) {
                        SM_LOG_ERROR(@"database query failed");
                        
                        [self triggerDBFailureWithSQLiteError:dbQueryError];
                        break;
                    }
                }
            } while(FALSE);
            
            [self closeDatabase:database];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if(dbOp.cancelled) {
                SM_LOG_DEBUG(@"DB op was cancelled");
                return;
            }
            
            getMessagesCountBlock(messagesCount);
        });
        
        const int32_t newSerialQueueLen = OSAtomicAdd32(-1, &_serialQueueLength);
        SM_LOG_NOISE(@"serial queue length decreased: %d", newSerialQueueLen);
    });
    
    return dbOp;
}

- (SMDatabaseOp*)loadMessageHeadersFromDBFolder:(NSString*)folderName offset:(NSUInteger)offset count:(NSUInteger)count getMessagesBlock:(void (^)(NSArray*, NSArray*))getMessagesBlock {
    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_NOISE(@"serial queue length increased: %d", serialQueueLen);
    
    SMDatabaseOp *dbOp = [[SMDatabaseOp alloc] init];
    
    dispatch_async(_serialQueue, ^{
        [self runUrgentTasks];
        
        if(dbOp.cancelled) {
            SM_LOG_DEBUG(@"DB op was cancelled");
            return;
        }
        
        NSMutableArray *messages = [NSMutableArray arrayWithCapacity:count];
        NSMutableArray *outgoingMessages = [NSMutableArray array];
        
        sqlite3 *database = [self openDatabase:DBOpenMode_Read];
        
        if(database != nil) {
            do {
                NSNumber *folderId = [_folderIds objectForKey:folderName];
                if(folderId == nil) {
                    SM_LOG_ERROR(@"No id for folder \"%@\" found in DB", folderName);

                    [self triggerDBFailure:DBFailure_CriticalDataNotFound];
                    break;
                }
                
                NSString *folderSelectSql = [NSString stringWithFormat:@"SELECT MESSAGE FROM FOLDER%@ ORDER BY UID DESC LIMIT %lu OFFSET %lu", folderId, count, offset];
                const char *folderSelectStmt = [folderSelectSql UTF8String];
                
                sqlite3_stmt *statement = NULL;
                const int sqlSelectPrepareResult = sqlite3_prepare_v2(database, folderSelectStmt, -1, &statement, NULL);
                
                BOOL dbQueryFailed = NO;
                int dbQueryError = SQLITE_OK;
                
                if(sqlSelectPrepareResult == SQLITE_OK) {
                    while(true) {
                        const int sqlStepResult = sqlite3_step(statement);
                        if(sqlStepResult == SQLITE_DONE) {
                            break;
                        }
                        else if(sqlStepResult != SQLITE_ROW) {
                            SM_LOG_ERROR(@"sqlite step error %d", sqlStepResult);
                            
                            dbQueryFailed = YES;
                            dbQueryError = sqlStepResult;
                            break;
                        }
                        
                        int dataSize = sqlite3_column_bytes(statement, 0);
                        NSData *data = [NSData dataWithBytesNoCopy:(void *)sqlite3_column_blob(statement, 0) length:dataSize freeWhenDone:NO];
                        NSData *uncompressedData = [SMCompression gzipInflate:data];
                        
                        NSObject *messageObject = [NSKeyedUnarchiver unarchiveObjectWithData:uncompressedData];
                        
                        if(messageObject == nil) {
                            SM_LOG_ERROR(@"could not decode message");
                            
                            dbQueryFailed = YES;
                            break;
                        }
                        
                        if([messageObject isKindOfClass:[SMMessageBuilder class]]) {
                            SMOutgoingMessage *outgoingMessage = [[SMOutgoingMessage alloc] initWithMessageBuilder:(SMMessageBuilder*)messageObject];

                            [outgoingMessages addObject:outgoingMessage];

                            SM_LOG_DEBUG(@"Outgoing message (uid %u, threadId %llu) loaded from folder %@", outgoingMessage.uid, outgoingMessage.threadId, folderName);
                        }
                        else {
                            NSAssert([messageObject isKindOfClass:[MCOIMAPMessage class]], @"unexpected class of messageObject: %@", [messageObject className]);
                            
                            [messages addObject:messageObject];

                            SM_LOG_DEBUG(@"IMAP message (uid %u, threadId %llu) loaded from folder %@", ((MCOIMAPMessage*)messageObject).uid, ((MCOIMAPMessage*)messageObject).gmailThreadID, folderName);
                        }
                    }
                }
                else {
                    SM_LOG_ERROR(@"could not prepare select statement from folder %@ (id %@), error %d", folderName, folderId, sqlSelectPrepareResult);

                    dbQueryFailed = YES;
                    dbQueryError = sqlSelectPrepareResult;
                }
                
                const int sqlFinalizeResult = sqlite3_finalize(statement);
                SM_LOG_NOISE(@"finalize message count statement result %d", sqlFinalizeResult);
                
                if(dbQueryFailed) {
                    SM_LOG_ERROR(@"database query failed");
                    
                    if(dbQueryError != SQLITE_OK) {
                        [self triggerDBFailureWithSQLiteError:dbQueryError];
                    }
                    else {
                        [self triggerDBFailure:DBFailure_CriticalDataNotFound];
                    }
                    
                    break;
                }
            } while(FALSE);
            
            [self closeDatabase:database];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if(dbOp.cancelled) {
                SM_LOG_DEBUG(@"DB op was cancelled");
                return;
            }
            
            getMessagesBlock(outgoingMessages, messages);
        });
        
        const int32_t newSerialQueueLen = OSAtomicAdd32(-1, &_serialQueueLength);
        SM_LOG_NOISE(@"serial queue length decreased: %d", newSerialQueueLen);
    });

    return dbOp;
}

- (SMDatabaseOp*)loadMessageHeaderForUIDFromDBFolder:(NSString*)folderName uid:(uint32_t)uid block:(void (^)(MCOIMAPMessage*))getMessageBlock {
    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_NOISE(@"serial queue length increased: %d", serialQueueLen);
    
    SMDatabaseOp *dbOp = [[SMDatabaseOp alloc] init];
    
    dispatch_async(_serialQueue, ^{
        [self runUrgentTasks];
        
        if(dbOp.cancelled) {
            SM_LOG_DEBUG(@"DB op was cancelled");
            return;
        }
        
        MCOIMAPMessage *message = nil;
        
        sqlite3 *database = [self openDatabase:DBOpenMode_Read];
        
        if(database != nil) {
            do {
                NSNumber *folderId = [_folderIds objectForKey:folderName];
                if(folderId == nil) {
                    SM_LOG_ERROR(@"No id for folder \"%@\" found in DB", folderName);
                    
                    [self triggerDBFailure:DBFailure_CriticalDataNotFound];
                    break;
                }
                
                message = [self loadMessageHeader:uid folderName:folderName folderId:folderId database:database];
            } while(FALSE);
            
            [self closeDatabase:database];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if(dbOp.cancelled) {
                SM_LOG_DEBUG(@"DB op was cancelled");
                return;
            }

            getMessageBlock(message);
        });
        
        const int32_t newSerialQueueLen = OSAtomicAdd32(-1, &_serialQueueLength);
        SM_LOG_NOISE(@"serial queue length decreased: %d", newSerialQueueLen);
    });
    
    return dbOp;
}

- (SMDatabaseOp*)loadMessageHeadersForUIDsFromDBFolder:(NSString*)folderName uids:(MCOIndexSet *)uids block:(void (^)(NSArray<MCOIMAPMessage*>*))getMessagesBlock {
    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_NOISE(@"serial queue length increased: %d", serialQueueLen);
    
    SMDatabaseOp *dbOp = [[SMDatabaseOp alloc] init];
    
    dispatch_async(_serialQueue, ^{
        [self runUrgentTasks];
        
        if(dbOp.cancelled) {
            SM_LOG_DEBUG(@"DB op was cancelled");
            return;
        }
        
        NSMutableArray *messages = [NSMutableArray array];
        
        sqlite3 *database = [self openDatabase:DBOpenMode_Read];
        
        if(database != nil) {
            do {
                NSNumber *folderId = [_folderIds objectForKey:folderName];
                if(folderId == nil) {
                    SM_LOG_ERROR(@"No id for folder \"%@\" found in DB", folderName);

                    [self triggerDBFailure:DBFailure_CriticalDataNotFound];
                    break;
                }

                if(uids.count > 0) {
                    // Enumerate messages in UID descending order.
                    // This way bodies for newer messages will be loaded sooner.
                    NSIndexSet *uidSet = [uids nsIndexSet];
                    for(NSUInteger uid = uidSet.lastIndex, count = 0; count < uidSet.count; uid = [uidSet indexLessThanIndex:uid], count++) {
                        MCOIMAPMessage *message = [self loadMessageHeader:(uint32_t)uid folderName:folderName folderId:folderId database:database];
                        
                        if(message != nil) {
                            [messages addObject:message];
                        }
                    }
                }
            } while(FALSE);
            
            [self closeDatabase:database];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if(dbOp.cancelled) {
                SM_LOG_DEBUG(@"DB op was cancelled");
                return;
            }
            
            getMessagesBlock(messages);
        });
        
        const int32_t newSerialQueueLen = OSAtomicAdd32(-1, &_serialQueueLength);
        SM_LOG_NOISE(@"serial queue length decreased: %d", newSerialQueueLen);
    });
    
    return dbOp;
}

- (MCOIMAPMessage*)loadMessageHeader:(uint32_t)uid folderName:(NSString*)folderName folderId:(NSNumber*)folderId database:(sqlite3*)database {
    MCOIMAPMessage *message = nil;
    
    BOOL dbQueryFailed = NO;
    int dbQueryError = SQLITE_OK;
    
    NSString *folderSelectSql = [NSString stringWithFormat:@"SELECT MESSAGE FROM FOLDER%@ WHERE UID = %u", folderId, uid];
    const char *folderSelectStmt = [folderSelectSql UTF8String];
    
    sqlite3_stmt *statement = NULL;
    const int sqlSelectPrepareResult = sqlite3_prepare_v2(database, folderSelectStmt, -1, &statement, NULL);
    
    if(sqlSelectPrepareResult == SQLITE_OK) {
        const int stepResult = sqlite3_step(statement);
        if(stepResult == SQLITE_ROW) {
            int dataSize = sqlite3_column_bytes(statement, 0);
            NSData *data = [NSData dataWithBytesNoCopy:(void *)sqlite3_column_blob(statement, 0) length:dataSize freeWhenDone:NO];
            NSData *uncompressedData = [SMCompression gzipInflate:data];
            
            message = [NSKeyedUnarchiver unarchiveObjectWithData:uncompressedData];
            if(message == nil) {
                SM_LOG_ERROR(@"could not decode IMAP message");
                
                dbQueryFailed = YES;
            }
        }
        else if(stepResult == SQLITE_DONE) {
            SM_LOG_DEBUG(@"message with uid %u from folder '%@' (%@) not found", uid, folderName, folderId);
        }
        else {
            SM_LOG_ERROR(@"could not load message with uid %u from folder %@ (id %@), error %d", uid, folderName, folderId, sqlSelectPrepareResult);
            
            dbQueryFailed = YES;
            dbQueryError = stepResult;
        }
    }
    else {
        SM_LOG_ERROR(@"could not prepare select statement for uid %u from folder %@ (id %@), error %d", uid, folderName, folderId, sqlSelectPrepareResult);
        
        dbQueryFailed = YES;
        dbQueryError = sqlSelectPrepareResult;
    }
    
    const int sqlFinalizeResult = sqlite3_finalize(statement);
    SM_LOG_NOISE(@"finalize message count statement result %d", sqlFinalizeResult);
    
    if(dbQueryFailed) {
        SM_LOG_ERROR(@"database query failed");
        
        if(dbQueryError != SQLITE_OK) {
            [self triggerDBFailureWithSQLiteError:dbQueryError];
        }
        else {
            [self triggerDBFailure:DBFailure_CriticalDataNotFound];
        }
    }
    
    return message;
}

- (SMDatabaseOp*)loadMessageBodyForUIDFromDB:(uint32_t)uid folderName:(NSString*)folderName urgent:(BOOL)urgent block:(void (^)(MCOMessageParser*, NSArray*, NSString*))getMessageBodyBlock {
    SMDatabaseOp *dbOp = [[SMDatabaseOp alloc] init];

    // Depending on the user requested urgency, we either select the
    // serial (FIFO) queue, or the concurrent one. In case of concurrent,
    // it won't have to wait while other non-urgent requests are processed.
    // Note that there may be heavy requests, so the serial
    // queue cannot be trusted in terms of response time.
    void (^op)() = ^{
        if(!urgent) {
            // Don't run other urgent ops that are waiting in the queue.
            // Otherwise it would lead to weird out of order op execution.
            [self runUrgentTasks];
        }
        
        if(dbOp.cancelled) {
            SM_LOG_DEBUG(@"DB op was cancelled");
            return;
        }
        
        NSNumber *folderId = [_folderIds objectForKey:folderName];
        if(folderId == nil) {
            SM_LOG_ERROR(@"no id for folder \"%@\" found in DB", folderName);

            dispatch_async(dispatch_get_main_queue(), ^{
                if(dbOp.cancelled) {
                    SM_LOG_DEBUG(@"DB op was cancelled");
                    return;
                }
                
                getMessageBodyBlock(nil, nil, nil);
            });
            
            return;
        }

        NSSet *uidSet = [_messagesWithBodies objectForKey:folderId];
        if(uidSet == nil) {
            SM_LOG_WARNING(@"folder '%@' (%@) is unknown", folderName, folderId);

            dispatch_async(dispatch_get_main_queue(), ^{
                if(dbOp.cancelled) {
                    SM_LOG_DEBUG(@"DB op was cancelled");
                    return;
                }
                
                getMessageBodyBlock(nil, nil, nil);
            });
            
            return;
        }
        
        if(![uidSet containsObject:[NSNumber numberWithUnsignedInt:uid]]) {
            SM_LOG_NOISE(@"no message body for message UID %u in the database", uid);

            dispatch_async(dispatch_get_main_queue(), ^{
                if(dbOp.cancelled) {
                    SM_LOG_DEBUG(@"DB op was cancelled");
                    return;
                }
                
                getMessageBodyBlock(nil, nil, nil);
            });

            return;
        }
        
        SM_LOG_NOISE(@"message UID %u has its body in the database", uid);
        
        NSString *messageBodyPreview = nil;
        MCOMessageParser *parser = nil;
        NSArray *attachments = nil;
        
        sqlite3 *database = [self openDatabase:DBOpenMode_Read];
        
        if(database != nil) {
            NSData *messageBody = nil;
            NSString *getMessageBodySql = [NSString stringWithFormat:@"SELECT MESSAGEBODY FROM MESSAGEBODIES%@ WHERE UID = \"%u\"", folderId, uid];
            
            sqlite3_stmt *statement = NULL;
            const int sqlPrepareResult = sqlite3_prepare_v2(database, [getMessageBodySql UTF8String], -1, &statement, NULL);
            
            if(sqlPrepareResult == SQLITE_OK) {
                const int sqlStepResult = sqlite3_step(statement);
                
                if(sqlStepResult == SQLITE_ROW) {
                    int dataSize = sqlite3_column_bytes(statement, 0);
                    NSData *data = [NSData dataWithBytesNoCopy:(void *)sqlite3_column_blob(statement, 0) length:dataSize freeWhenDone:NO];
                    NSData *uncompressedData = [SMCompression gzipInflate:data];
                    
                    messageBody = uncompressedData;
                }
                else if(sqlStepResult == SQLITE_DONE) {
                    SM_LOG_DEBUG(@"message body (UID %u) not found in the database folder %@ (id %@)", uid, folderName, folderId);
                }
                else {
                    SM_LOG_ERROR(@"sqlite3_step error %d", sqlStepResult);
                    
                    [self triggerDBFailureWithSQLiteError:sqlStepResult];
                }
            }
            else {
                SM_LOG_ERROR(@"could not prepare load statement, error %d", sqlPrepareResult);

                [self triggerDBFailureWithSQLiteError:sqlPrepareResult];
            }
            
            const int sqlFinalizeResult = sqlite3_finalize(statement);
            SM_LOG_NOISE(@"finalize message count statement result %d", sqlFinalizeResult);
            
            [self closeDatabase:database];
            
            if(messageBody != nil) {
                parser = [MCOMessageParser messageParserWithData:messageBody];
                attachments = parser.attachments; // note that this is potentially long operation, so do it in the current thread, not in the main thread
                
                // TODO: load the plain text from database to avoid extra heavy work in MCOMessageParser
                
                messageBodyPreview = [SMMessage imapMessagePlainTextBody:parser];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if(dbOp.cancelled) {
                SM_LOG_DEBUG(@"DB op was cancelled");
                return;
            }
            
            getMessageBodyBlock(parser, attachments, messageBodyPreview);
        });
        
        const int32_t newSerialQueueLen = OSAtomicAdd32(-1, &_serialQueueLength);
        SM_LOG_NOISE(@"serial queue length decreased: %d", newSerialQueueLen);
    };

    [self dispatchOp:op urgent:urgent];
    
    return dbOp;
}

- (NSData*)encodeImapMessage:(MCOIMAPMessage*)imapMessage {
    NSData *encodedMessage = [NSKeyedArchiver archivedDataWithRootObject:imapMessage];
    NSAssert(encodedMessage != nil, @"could not encode IMAP message");
    
    NSData *compressedMessage = [SMCompression gzipDeflate:encodedMessage];
    
    SM_LOG_DEBUG(@"message UID %u, data len %lu, compressed len %lu (%lu%% from original)", imapMessage.uid, encodedMessage.length, compressedMessage.length, compressedMessage.length/(encodedMessage.length/100));
    
    return compressedMessage;
}

- (NSData*)encodeMessageBuilder:(SMMessageBuilder*)messageBuilder {
    NSData *encodedMessageBuilder = [NSKeyedArchiver archivedDataWithRootObject:messageBuilder];
    NSAssert(encodedMessageBuilder != nil, @"could not encode outgoing message builder");
    
    NSData *compressedMessageBuilder = [SMCompression gzipDeflate:encodedMessageBuilder];
    
    SM_LOG_DEBUG(@"message builder data len %lu, compressed len %lu (%lu%% from original)", encodedMessageBuilder.length, compressedMessageBuilder.length, compressedMessageBuilder.length/(compressedMessageBuilder.length/100));
    
    return compressedMessageBuilder;
}

- (void)getMessageContacts:(MCOIMAPMessage*)imapMessage from:(NSString**)from to:(NSString**)to cc:(NSString**)cc {
    *to = @"";

    NSArray<MCOAddress*> *toAddresses = imapMessage.header.to;
    for(NSUInteger i = 0, n = toAddresses.count; i < n; i++) {
        *to = [*to stringByAppendingString:[SMAddress displayAddress:toAddresses[i].nonEncodedRFC822String]];

        if(i + 1 < n) {
            *to = [*to stringByAppendingString:@"|"];
        }
    }

    *cc = @"";
    NSArray<MCOAddress*> *ccAddresses = imapMessage.header.cc;
    for(NSUInteger i = 0, n = ccAddresses.count; i < n; i++) {
        *cc = [*cc stringByAppendingString:[SMAddress displayAddress:ccAddresses[i].nonEncodedRFC822String]];
        
        if(i + 1 < n) {
            *cc = [*cc stringByAppendingString:@"|"];
        }
    }

    *from = [SMAddress displayAddress:imapMessage.header.from.nonEncodedRFC822String];
}

- (void)putMessageToDBFolder:(MCOIMAPMessage*)imapMessage folder:(NSString*)folderName {
    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_NOISE(@"serial queue length increased: %d", serialQueueLen);
    
    dispatch_async(_serialQueue, ^{
        [self runUrgentTasks];

        NSNumber *folderId = [_folderIds objectForKey:folderName];
        if(folderId != nil) {
            NSData *encodedMessage = [self encodeImapMessage:imapMessage];
            [self storeEncodedMessage:encodedMessage uid:imapMessage.uid date:imapMessage.header.date folderId:folderId];
            
            NSString *from, *to, *cc;
            [self getMessageContacts:imapMessage from:&from to:&to cc:&cc];
            [self storeMessageTextInfo:imapMessage.uid from:from to:to cc:cc subject:imapMessage.header.subject folderId:folderId];
        }
        else {
            SM_LOG_ERROR(@"No id for folder \"%@\" found in DB", folderName);
            
            [self triggerDBFailure:DBFailure_CriticalDataNotFound];
        }
        
        const int32_t newSerialQueueLen = OSAtomicAdd32(-1, &_serialQueueLength);
        SM_LOG_NOISE(@"serial queue length decreased: %d", newSerialQueueLen);
    });
}

- (void)putOutgoingMessageToDBFolder:(SMOutgoingMessage*)outgoingMessage folder:(NSString*)folderName {
    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_NOISE(@"serial queue length increased: %d", serialQueueLen);
    
    dispatch_async(_serialQueue, ^{
        [self runUrgentTasks];
        
        NSNumber *folderId = [_folderIds objectForKey:folderName];
        if(folderId != nil) {
            NSData *encodedMessageBuilder = [self encodeMessageBuilder:outgoingMessage.messageBuilder];
            [self storeEncodedMessage:encodedMessageBuilder uid:outgoingMessage.uid date:outgoingMessage.date folderId:folderId];
            
            // TODO: contacts/subject/body for search?
        }
        else {
            SM_LOG_ERROR(@"No id for folder \"%@\" found in DB", folderName);
            
            [self triggerDBFailure:DBFailure_CriticalDataNotFound];
        }
        
        const int32_t newSerialQueueLen = OSAtomicAdd32(-1, &_serialQueueLength);
        SM_LOG_NOISE(@"serial queue length decreased: %d", newSerialQueueLen);
    });
}

- (void)storeMessageTextInfo:(uint32_t)uid from:(NSString*)from to:(NSString*)to cc:(NSString*)cc subject:(NSString*)subject folderId:(NSNumber*)folderId {
    sqlite3 *database = [self openDatabase:DBOpenMode_ReadWrite];
    
    if(database != nil) {
        do {
            NSString *insertSql = [NSString stringWithFormat:@"INSERT INTO MESSAGETEXT%@ (\"docid\", \"FROM\", \"TO\", \"CC\", \"SUBJECT\") VALUES (?, ?, ?, ?, ?)", folderId];
            
            sqlite3_stmt *statement = NULL;
            const int sqlPrepareResult = sqlite3_prepare_v2(database, insertSql.UTF8String, -1, &statement, NULL);
            
            if(sqlPrepareResult != SQLITE_OK) {
                SM_LOG_ERROR(@"could not prepare insert text statement, error %d", sqlPrepareResult);
                
                [self triggerDBFailureWithSQLiteError:sqlPrepareResult];
                break;
            }
            
            BOOL dbQueryFailed = NO;
            int dbQueryError = SQLITE_OK;
            
            do {
                int bindResult;
                
                if((bindResult = sqlite3_bind_int(statement, 1, uid)) != SQLITE_OK) {
                    SM_LOG_ERROR(@"message UID %u, could not bind argument 1 (UID), error %d", uid, bindResult);
                    
                    dbQueryFailed = YES;
                    dbQueryError = bindResult;
                    break;
                }
                
                if((bindResult = sqlite3_bind_text(statement, 2, from.UTF8String, -1, NULL)) != SQLITE_OK) {
                    SM_LOG_ERROR(@"message UID %u, could not bind argument 2 (FROM), error %d", uid, bindResult);
                    
                    dbQueryFailed = YES;
                    dbQueryError = bindResult;
                    break;
                }
                
                if((bindResult = sqlite3_bind_text(statement, 3, to.UTF8String, -1, NULL)) != SQLITE_OK) {
                    SM_LOG_ERROR(@"message UID %u, could not bind argument 3 (TO), error %d", uid, bindResult);
                    
                    dbQueryFailed = YES;
                    dbQueryError = bindResult;
                    break;
                }
                
                if((bindResult = sqlite3_bind_text(statement, 4, cc.UTF8String, -1, NULL)) != SQLITE_OK) {
                    SM_LOG_ERROR(@"message UID %u, could not bind argument 4 (CC), error %d", uid, bindResult);
                    
                    dbQueryFailed = YES;
                    dbQueryError = bindResult;
                    break;
                }
                
                if((bindResult = sqlite3_bind_text(statement, 5, subject.UTF8String, -1, NULL)) != SQLITE_OK) {
                    SM_LOG_ERROR(@"message UID %u, could not bind argument 5 (SUBJECT), error %d", uid, bindResult);
                    
                    dbQueryFailed = YES;
                    dbQueryError = bindResult;
                    break;
                }
                
                const int sqlInsertResult = sqlite3_step(statement);
                if(sqlInsertResult == SQLITE_DONE) {
                    SM_LOG_DEBUG(@"Message text with UID %u successfully inserted", uid);
                } else if(sqlInsertResult == SQLITE_CONSTRAINT) {
                    SM_LOG_INFO(@"Message text with UID %u already exists", uid);
                } else {
                    SM_LOG_ERROR(@"Failed to insert message text with UID %u, error %d", uid, sqlInsertResult);
                    
                    dbQueryFailed = YES;
                    dbQueryError = sqlInsertResult;
                    break;
                }
            } while(FALSE);
            
            const int sqlFinalizeResult = sqlite3_finalize(statement);
            SM_LOG_NOISE(@"finalize messages insert statement result %d", sqlFinalizeResult);
            
            if(dbQueryFailed) {
                SM_LOG_ERROR(@"SQL query has failed");
                
                [self triggerDBFailureWithSQLiteError:dbQueryError];
                break;
            }
        } while(FALSE);
        
        [self closeDatabase:database];
    }
}

- (SMDatabaseOp*)findMessages:(NSString*)folderName tokens:(NSArray<SMSearchToken*>*)tokens contact:(NSString*)contact subject:(NSString*)subject content:(NSString*)content block:(void (^)(NSArray<SMTextMessage*>*))getTextMessagesBlock {
    SMDatabaseOp *dbOp = [[SMDatabaseOp alloc] init];

    void (^op)() = ^{
        if(dbOp.cancelled) {
            SM_LOG_DEBUG(@"DB op was cancelled");
            return;
        }

        NSMutableArray<SMTextMessage*> *textMessages = [NSMutableArray array];
        
        sqlite3 *database = [self openDatabase:DBOpenMode_ReadWrite];
        
        if(database != nil) {
            do {
                NSNumber *folderId = [_folderIds objectForKey:folderName];
                if(folderId == nil) {
                    SM_LOG_ERROR(@"No id for folder \"%@\" found in DB", folderName);
                    break;
                }
                
                NSString *selectSql = [NSString stringWithFormat:@"SELECT \"docid\", \"FROM\", \"TO\", \"CC\", \"SUBJECT\" FROM MESSAGETEXT%@ WHERE MESSAGETEXT%@ MATCH ", folderId, folderId];
                
                selectSql = [selectSql stringByAppendingString:@"'"];

                // Encode the primary search criteria.
                if(contact && contact.length > 0) {
                    selectSql = [selectSql stringByAppendingString:[NSString stringWithFormat:@"(FROM: %@ OR TO: %@ OR CC: %@) ", contact, contact, contact]];
                }
                else if(subject && subject.length > 0) {
                    selectSql = [selectSql stringByAppendingString:[NSString stringWithFormat:@"SUBJECT: %@ ", subject]];
                }
                else if(content && content.length > 0) {
                    selectSql = [selectSql stringByAppendingString:[NSString stringWithFormat:@"MESSAGEBODY: %@ ", content]];
                }
                else if(tokens == nil || tokens.count == 0) {
                    SM_FATAL(@"no tokens, contact, subject or content specified as main search criteria");
                }
                
                // Encode the secondary search criteria.
                if(tokens != nil && tokens.count != 0) {
                    for(SMSearchToken *token in tokens) {
                        NSString *requestStr = nil;

                        switch(token.kind) {
                            case SMSearchExpressionKind_To:
                                requestStr = @"TO";
                                break;
                                
                            case SMSearchExpressionKind_From:
                                requestStr = @"FROM";
                                break;
                                
                            case SMSearchExpressionKind_Cc:
                                requestStr = @"CC";
                                break;
                                
                            case SMSearchExpressionKind_Subject:
                                requestStr = @"SUBJECT";
                                break;
                                
                            case SMSearchExpressionKind_Content:
                                requestStr = @"MESSAGEBODY";
                                break;
                                
                            default:
                                SM_FATAL(@"unknown token kind %lu", token.kind);
                                break;
                        }

                        if((token.kind == SMSearchExpressionKind_To) || (token.kind == SMSearchExpressionKind_From) || (token.kind == SMSearchExpressionKind_Cc)) {
                            NSString *contactName = nil;
                            NSString *email = [SMAddress extractEmailFromAddressString:token.string name:&contactName];
                        
                            if(contactName != nil && email != nil) {
                                selectSql = [selectSql stringByAppendingString:[NSString stringWithFormat:@"AND (%@: %@ OR %@: %@) ", requestStr, contactName, requestStr, email]];
                            }
                            else if(contactName != nil) {
                                selectSql = [selectSql stringByAppendingString:[NSString stringWithFormat:@"%@: %@ ", requestStr, contactName]];
                            }
                            else if(email != nil) {
                                selectSql = [selectSql stringByAppendingString:[NSString stringWithFormat:@"%@: %@ ", requestStr, email]];
                            }
                        }
                        else {
                            selectSql = [selectSql stringByAppendingString:[NSString stringWithFormat:@"%@: %@ ", requestStr, token.string]];
                        }
                    }
                }
                
                selectSql = [selectSql stringByAppendingString:@"'"];
                
                SM_LOG_INFO(@"Request: %@", selectSql);
                
                sqlite3_stmt *selectStatement = NULL;
                const int sqlSelectPrepareResult = sqlite3_prepare_v2(database, selectSql.UTF8String, -1, &selectStatement, NULL);
                
                if(sqlSelectPrepareResult != SQLITE_OK) {
                    SM_LOG_ERROR(@"could not prepare select statement, error %d (%s)", sqlSelectPrepareResult, sqlite3_errmsg(database));
                    break;
                }
                
                BOOL dbQueryFailed = NO;
                int dbQueryError = SQLITE_OK;
                
                while(true) {
                    const int sqlLoadResult = sqlite3_step(selectStatement);
                    if(sqlLoadResult == SQLITE_ROW) {
                        NSString *from = nil, *to = nil, *cc = nil; // TODO
                        
                        uint32_t uid = sqlite3_column_int(selectStatement, 0);
                        
                        const char *fromText = (const char *)sqlite3_column_text(selectStatement, 1);
                        NSString *fromString = (fromText != NULL? [NSString stringWithUTF8String:fromText] : nil);
                        NSArray<NSString*> *fromList = [self filterAddressList:fromString contactToFilter:(contact != nil? contact : from)];
                        
                        const char *toText = (const char *)sqlite3_column_text(selectStatement, 2);
                        NSString *toString = (toText != NULL? [NSString stringWithUTF8String:toText] : nil);
                        NSArray<NSString*> *toList = [self filterAddressList:toString contactToFilter:(contact != nil? contact : to)];

                        const char *ccText = (const char *)sqlite3_column_text(selectStatement, 3);
                        NSString *ccString = (ccText != NULL? [NSString stringWithUTF8String:ccText] : nil);
                        NSArray<NSString*> *ccList = [self filterAddressList:ccString contactToFilter:(contact != nil? contact : cc)];
                        
                        const char *subjectText = (const char *)sqlite3_column_text(selectStatement, 4);
                        NSString *subject = (subjectText != NULL? [NSString stringWithUTF8String:subjectText] : nil);
                        
                        SMTextMessage *textMessage = [[SMTextMessage alloc] initWithUID:uid from:(fromList.count > 0? fromList.firstObject : nil) toList:toList ccList:ccList subject:subject];
                        
                        [textMessages addObject:textMessage];
                    }
                    else if(sqlLoadResult == SQLITE_DONE) {
                        break;
                    }
                    else {
                        SM_LOG_ERROR(@"failed to load text messages, folder %@, error %d (%s)", folderId, sqlLoadResult, sqlite3_errmsg(database));
                        
                        dbQueryFailed = YES;
                        dbQueryError = sqlLoadResult;
                        break;
                    }
                } while(FALSE);
                
                const int sqlFinalizeResult = sqlite3_finalize(selectStatement);
                SM_LOG_NOISE(@"finalize messages select statement result %d", sqlFinalizeResult);
                
                if(dbQueryFailed) {
                    SM_LOG_ERROR(@"SQL query has failed");
                    break;
                }
            } while(FALSE);
            
            [self closeDatabase:database];
        }
        
/* TODO (do we care?)
 
        // Sort messages by descending UIDs (new messages first).
        [textMessages sortUsingComparator:^NSComparisonResult(id a, id b) {
            SMTextMessage *m1 = (SMTextMessage*)a;
            SMTextMessage *m2 = (SMTextMessage*)b;
            
            if(m1.uid > m2.uid) {
                return NSOrderedAscending;
            }
            else if(m1.uid < m2.uid) {
                return NSOrderedDescending;
            }
            else {
                return NSOrderedSame;
            }
        }];
*/
        dispatch_async(dispatch_get_main_queue(), ^{
            if(dbOp.cancelled) {
                SM_LOG_DEBUG(@"DB op was cancelled");
                return;
            }
            
            getTextMessagesBlock(textMessages);
        });
    };

    [self dispatchOp:op urgent:YES];
    
    return dbOp;
}

- (NSArray<NSString*>*)filterAddressList:(NSString*)addressListString contactToFilter:(NSString*)contactToFilter {
    if(addressListString == nil || contactToFilter == nil) {
        return nil;
    }
    
    contactToFilter = contactToFilter.lowercaseString;
    
    NSArray<NSString*> *addressList = [addressListString componentsSeparatedByString:@"|"];
    NSMutableArray<NSString*> *filteredAddressList = [NSMutableArray array];
    
    for(NSString *address in addressList) {
        NSString *addressLowercase = address.lowercaseString;
        
        if([addressLowercase containsString:contactToFilter]) {
            [filteredAddressList addObject:address];
        }
    }
    
    return filteredAddressList;
}

- (void)storeEncodedMessage:(NSData*)encodedMessage uid:(uint32_t)uid date:(NSDate*)date folderId:(NSNumber*)folderId {
    sqlite3 *database = [self openDatabase:DBOpenMode_ReadWrite];
    
    if(database != nil) {
        do {
            NSString *folderInsertSql = [NSString stringWithFormat:@"INSERT INTO FOLDER%@ (\"UID\", \"TIMESTAMP\", \"MESSAGE\") VALUES (?, ?, ?)", folderId];
            const char *folderInsertStmt = [folderInsertSql UTF8String];
            
            sqlite3_stmt *statement = NULL;
            const int sqlPrepareResult = sqlite3_prepare_v2(database, folderInsertStmt, -1, &statement, NULL);
            if(sqlPrepareResult != SQLITE_OK) {
                SM_LOG_ERROR(@"could not prepare load statement, error %d", sqlPrepareResult);
                
                [self triggerDBFailureWithSQLiteError:sqlPrepareResult];
                break;
            }
            
            BOOL dbQueryFailed = NO;
            int dbQueryError = SQLITE_OK;
            
            do {
                int bindResult;
                if((bindResult = sqlite3_bind_int(statement, 1, uid)) != SQLITE_OK) {
                    SM_LOG_ERROR(@"message UID %u, could not bind argument 1 (UID), error %d", uid, bindResult);
                    
                    dbQueryFailed = YES;
                    dbQueryError = bindResult;
                    break;
                }
                
                NSTimeInterval messageDateSeconds = [date timeIntervalSince1970];
                uint64_t timestamp = (uint64_t)messageDateSeconds;
                
                if((bindResult = sqlite3_bind_int64(statement, 2, timestamp)) != SQLITE_OK) {
                    SM_LOG_ERROR(@"message UID %u, could not bind argument 2 (TIMESTAMP), error %d", uid, bindResult);
                    
                    dbQueryFailed = YES;
                    dbQueryError = bindResult;
                    break;
                }
                
                if((bindResult = sqlite3_bind_blob(statement, 3, encodedMessage.bytes, (int)encodedMessage.length, SQLITE_STATIC)) != SQLITE_OK) {
                    SM_LOG_ERROR(@"message UID %u, could not bind argument 3 (MESSAGE), error %d", uid, bindResult);
                    
                    dbQueryFailed = YES;
                    dbQueryError = bindResult;
                    break;
                }
                
                const int sqlStepResult = sqlite3_step(statement);
                
                if(sqlStepResult != SQLITE_DONE) {
                    if(sqlStepResult == SQLITE_CONSTRAINT) {
                        SM_LOG_WARNING(@"Message with UID %u already in folder id %@", uid, folderId);
                    }
                    else {
                        SM_LOG_ERROR(@"Failed to insert message with UID %u in folder id %@, error %d", uid, folderId, sqlStepResult);
                        
                        dbQueryFailed = YES;
                        dbQueryError = sqlStepResult;
                        break;
                    }
                }
            } while(FALSE);
            
            const int sqlFinalizeResult = sqlite3_finalize(statement);
            SM_LOG_NOISE(@"finalize folders insert statement result %d", sqlFinalizeResult);
            
            if(dbQueryFailed) {
                SM_LOG_ERROR(@"SQL query has failed");
                
                [self triggerDBFailureWithSQLiteError:dbQueryError];
                break;
            }
            
            SM_LOG_DEBUG(@"Message with UID %u successfully inserted to folder id %@", uid, folderId);
        } while(FALSE);
        
        [self closeDatabase:database];
    }
}

- (void)updateMessageInDBFolder:(MCOIMAPMessage*)imapMessage folder:(NSString*)folderName {
    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_NOISE(@"serial queue length increased: %d", serialQueueLen);
    
    dispatch_async(_serialQueue, ^{
        [self runUrgentTasks];

        sqlite3 *database = [self openDatabase:DBOpenMode_ReadWrite];
        
        if(database != nil) {
            do {
                NSNumber *folderId = [_folderIds objectForKey:folderName];
                if(folderId == nil) {
                    SM_LOG_ERROR(@"No id for folder \"%@\" found in DB", folderName);
                    
                    [self triggerDBFailure:DBFailure_CriticalDataNotFound];
                    break;
                }
                
                NSString *updateSql = [NSString stringWithFormat:@"UPDATE FOLDER%@ SET MESSAGE = ? WHERE UID = %u", folderId, imapMessage.uid];
                const char *updateStmt = [updateSql UTF8String];
                
                sqlite3_stmt *statement = NULL;
                const int sqlPrepareResult = sqlite3_prepare_v2(database, updateStmt, -1, &statement, NULL);
                if(sqlPrepareResult != SQLITE_OK) {
                    SM_LOG_ERROR(@"could not prepare update statement, error %d", sqlPrepareResult);
                    
                    [self triggerDBFailureWithSQLiteError:sqlPrepareResult];
                    break;
                }
                
                NSData *encodedMessage = [self encodeImapMessage:imapMessage];
                
                BOOL dbQueryFailed = NO;
                int dbQueryError = SQLITE_OK;
                
                do {
                    const int bindResult = sqlite3_bind_blob(statement, 1, encodedMessage.bytes, (int)encodedMessage.length, SQLITE_STATIC);
                    if(bindResult != SQLITE_OK) {
                        SM_LOG_ERROR(@"message UID %u, could not bind argument 1 (MESSAGE), error %d", imapMessage.uid, bindResult);
                        
                        dbQueryFailed = YES;
                        dbQueryError = bindResult;
                        break;
                    }
                    
                    const int sqlResult = sqlite3_step(statement);
                    
                    if(sqlResult != SQLITE_DONE) {
                        SM_LOG_ERROR(@"Failed to upated message with UID %u in folder \"%@\" (id %@), error %d", imapMessage.uid, folderName, folderId, sqlResult);
                        
                        dbQueryFailed = YES;
                        dbQueryError = sqlResult;
                        break;
                    }
                } while(FALSE);
                
                const int sqlFinalizeResult = sqlite3_finalize(statement);
                SM_LOG_NOISE(@"finalize folders insert statement result %d", sqlFinalizeResult);
                
                if(dbQueryFailed) {
                    SM_LOG_ERROR(@"SQL query has failed");
                    
                    [self triggerDBFailureWithSQLiteError:dbQueryError];
                    break;
                }
                
                SM_LOG_DEBUG(@"Message with UID %u successfully udpated in folder \"%@\" (id %@)", imapMessage.uid, folderName, folderId);
            } while(FALSE);
            
            [self closeDatabase:database];
        }
        
        const int32_t newSerialQueueLen = OSAtomicAdd32(-1, &_serialQueueLength);
        SM_LOG_NOISE(@"serial queue length decreased: %d", newSerialQueueLen);
    });
}

- (void)removeMessageFromDBFolder:(uint32_t)uid folder:(NSString*)folderName {
    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_NOISE(@"serial queue length increased: %d", serialQueueLen);
    
    dispatch_async(_serialQueue, ^{
        [self runUrgentTasks];

        NSNumber *folderId = [_folderIds objectForKey:folderName];
        if(folderId == nil) {
            SM_LOG_ERROR(@"attempt to delete message UID %u: no id for folder \"%@\" found in DB", uid, folderName);
            return;
        }
        
        sqlite3 *database = [self openDatabase:DBOpenMode_ReadWrite];
        
        if(database != nil) {
            do {
                //
                // Step 1: Remove message header with the given UID from the folder table.
                //
                NSMutableSet *uidSet = [_messagesWithBodies objectForKey:folderId];
                if(uidSet == nil) {
                    SM_LOG_WARNING(@"folder '%@' (%@) is unknown", folderName, folderId);
                }
                else {
                    [uidSet removeObject:[NSNumber numberWithUnsignedInt:uid]];
                }
                
                {
                    NSString *removeSql = [NSString stringWithFormat:@"DELETE FROM FOLDER%@ WHERE UID = \"%u\"", folderId, uid];
                    const char *removeStmt = [removeSql UTF8String];
                    
                    sqlite3_stmt *statement = NULL;
                    const int sqlPrepareResult = sqlite3_prepare_v2(database, removeStmt, -1, &statement, NULL);
                    if(sqlPrepareResult != SQLITE_OK) {
                        SM_LOG_ERROR(@"Could not prepare remove statement for message UID %u, folder %@ (%@), error %d", uid, folderName, folderId, sqlPrepareResult);
                        
                        [self triggerDBFailureWithSQLiteError:sqlPrepareResult];
                        break;
                    }
                    
                    int sqlResult = sqlite3_step(statement);
                    if(sqlResult == SQLITE_DONE) {
                        SM_LOG_DEBUG(@"Message UID %u successfully removed from folder %@ (%@)", uid, folderName, folderId);
                    } else {
                        // Don't consider it critical. Should we?
                        SM_LOG_WARNING(@"Could not remove message UID %u from folder %@ (%@)", uid, folderName, folderId);
                    }
                    
                    const int sqlFinalizeResult = sqlite3_finalize(statement);
                    SM_LOG_NOISE(@"finalize folders remove statement result %d", sqlFinalizeResult);
                }
                
                //
                // Step 2: Remove the message body from the bodies table.
                //
                {
                    NSString *removeSql = [NSString stringWithFormat:@"DELETE FROM MESSAGEBODIES%@ WHERE UID = \"%u\"", folderId, uid];
                    const char *removeStmt = [removeSql UTF8String];
                    
                    sqlite3_stmt *statement = NULL;
                    const int sqlPrepareResult = sqlite3_prepare_v2(database, removeStmt, -1, &statement, NULL);
                    if(sqlPrepareResult != SQLITE_OK) {
                        SM_LOG_ERROR(@"Could not prepare message body (UID %u) remove statement for folder '%@' (%@), error %d", uid, folderName, folderId, sqlPrepareResult);

                        [self triggerDBFailureWithSQLiteError:sqlPrepareResult];
                        break;
                    }
                    
                    int sqlResult = sqlite3_step(statement);
                    if(sqlResult == SQLITE_DONE) {
                        SM_LOG_DEBUG(@"Message body with UID %u successfully removed from message bodies table for folder '%@' (%@)", uid, folderName, folderId);
                    } else {
                        // Don't consider it critical. Should we?
                        SM_LOG_WARNING(@"Could not remove message body with UID %u for folder '%@' (%@), error %d", uid, folderName, folderId, sqlResult);
                    }
                    
                    const int sqlFinalizeResult = sqlite3_finalize(statement);
                    SM_LOG_NOISE(@"finalize message body remove statement result %d", sqlFinalizeResult);
                }
                
                //
                // Step 3: Remove the message from the text table.
                //
                {
                    NSString *removeSql = [NSString stringWithFormat:@"DELETE FROM MESSAGETEXT%@ WHERE docid = \"%u\"", folderId, uid];
                    const char *removeStmt = [removeSql UTF8String];
                    
                    sqlite3_stmt *statement = NULL;
                    const int sqlPrepareResult = sqlite3_prepare_v2(database, removeStmt, -1, &statement, NULL);
                    if(sqlPrepareResult != SQLITE_OK) {
                        SM_LOG_ERROR(@"Could not prepare message text (docid %u) remove statement for folder '%@' (%@), error %d", uid, folderName, folderId, sqlPrepareResult);
                        
                        [self triggerDBFailureWithSQLiteError:sqlPrepareResult];
                        break;
                    }
                    
                    int sqlResult = sqlite3_step(statement);
                    if(sqlResult == SQLITE_DONE) {
                        SM_LOG_DEBUG(@"Message text with docid %u successfully removed from message bodies table for folder '%@' (%@)", uid, folderName, folderId);
                    } else {
                        // Don't consider it critical. Should we?
                        SM_LOG_WARNING(@"Could not remove message text with docid %u for folder '%@' (%@), error %d", uid, folderName, folderId, sqlResult);
                    }
                    
                    const int sqlFinalizeResult = sqlite3_finalize(statement);
                    SM_LOG_NOISE(@"finalize message text remove statement result %d", sqlFinalizeResult);
                }
            } while(FALSE);
            
            [self closeDatabase:database];
        }
        
        const int32_t newSerialQueueLen = OSAtomicAdd32(-1, &_serialQueueLength);
        SM_LOG_NOISE(@"serial queue length decreased: %d", newSerialQueueLen);
    });
}

- (void)putMessageBodyToDB:(uint32_t)uid messageDate:(NSDate*)messageDate data:(NSData*)data plainTextBody:(NSString*)plainTextBody folderName:(NSString*)folderName {
    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_NOISE(@"serial queue length increased: %d", serialQueueLen);
    
    dispatch_async(_serialQueue, ^{
        [self runUrgentTasks];

        NSNumber *folderId = [_folderIds objectForKey:folderName];
        if(folderId == nil) {
            SM_LOG_ERROR(@"No id for folder \"%@\" found in DB", folderName);
            
            [self triggerDBFailure:DBFailure_CriticalDataNotFound];
            return;
        }
        
        NSMutableSet *uidSet = [_messagesWithBodies objectForKey:folderId];
        if(uidSet == nil) {
            SM_LOG_ERROR(@"folder '%@' (%@) is unknown", folderName, folderId);
        }
        else if([uidSet containsObject:[NSNumber numberWithUnsignedInt:uid]]) {
            SM_LOG_DEBUG(@"message with UID %u (folder %@) already has its body in the database", uid, folderName);
            return;
        }
        
        sqlite3 *database = [self openDatabase:DBOpenMode_ReadWrite];
        
        if(database != nil) {
            BOOL dbQueryFailed = NO;

            //
            // Step 1: Save the message body along with the meta info.
            //
            do {
                NSString *insertSql = [NSString stringWithFormat:@"INSERT INTO MESSAGEBODIES%@ (\"UID\", \"TIMESTAMP\", \"MESSAGEBODY\") VALUES (?, ?, ?)", folderId];
                
                sqlite3_stmt *statement = NULL;
                const int sqlPrepareResult = sqlite3_prepare_v2(database, insertSql.UTF8String, -1, &statement, NULL);
                
                if(sqlPrepareResult != SQLITE_OK) {
                    SM_LOG_ERROR(@"could not prepare insert body statement, error %d", sqlPrepareResult);
                    
                    [self triggerDBFailureWithSQLiteError:sqlPrepareResult];
                    break;
                }
                
                int dbQueryError = SQLITE_OK;
                
                do {
                    int bindResult;
                    if((bindResult = sqlite3_bind_int(statement, 1, uid)) != SQLITE_OK) {
                        SM_LOG_ERROR(@"message UID %u, could not bind argument 1 (UID), error %d", uid, bindResult);
                        
                        dbQueryFailed = YES;
                        dbQueryError = bindResult;
                        break;
                    }
                    
                    NSTimeInterval messageDateSeconds = [messageDate timeIntervalSince1970];
                    uint64_t timestamp = (uint64_t)messageDateSeconds;

                    if((bindResult = sqlite3_bind_int64(statement, 2, timestamp)) != SQLITE_OK) {
                        SM_LOG_ERROR(@"message UID %u, could not bind argument 2 (TIMESTAMP), error %d", uid, bindResult);
                        
                        dbQueryFailed = YES;
                        dbQueryError = bindResult;
                        break;
                    }

                    NSData *compressedData = [SMCompression gzipDeflate:data];
                    NSAssert(compressedData != nil, @"compressed data is nil");
                    
                    SM_LOG_DEBUG(@"message UID %u, data len %lu, compressed len %lu (%lu%% from original)", uid, data.length, compressedData.length, compressedData.length/(data.length/100));
                    
                    if((bindResult = sqlite3_bind_blob(statement, 3, compressedData.bytes, (int)compressedData.length, SQLITE_STATIC)) != SQLITE_OK) {
                        SM_LOG_ERROR(@"message UID %u, could not bind argument 3 (MESSAGEBODY), error %d", uid, bindResult);
                        
                        dbQueryFailed = YES;
                        dbQueryError = bindResult;
                        break;
                    }
                    
                    const int sqlInsertResult = sqlite3_step(statement);
                    if(sqlInsertResult == SQLITE_DONE) {
                        SM_LOG_DEBUG(@"Message body with UID %u successfully inserted", uid);
                    } else if(sqlInsertResult == SQLITE_CONSTRAINT) {
                        SM_LOG_INFO(@"Message body with UID %u already exists", uid);
                    } else {
                        SM_LOG_ERROR(@"Failed to insert message body with UID %u, error %d", uid, sqlInsertResult);
                        
                        dbQueryFailed = YES;
                        dbQueryError = sqlInsertResult;
                        break;
                    }
                } while(FALSE);
                
                const int sqlFinalizeResult = sqlite3_finalize(statement);
                SM_LOG_NOISE(@"finalize messages insert statement result %d", sqlFinalizeResult);
                
                if(dbQueryFailed) {
                    SM_LOG_ERROR(@"SQL query has failed");
                    
                    [self triggerDBFailureWithSQLiteError:dbQueryError];
                    break;
                }
            } while(FALSE);

            //
            // Step 2: Save the message text body
            //
            do {
                NSString *updateSql = [NSString stringWithFormat:@"UPDATE MESSAGETEXT%@ SET MESSAGEBODY = ? WHERE docid = %u", folderId, uid];
                
                sqlite3_stmt *statement = NULL;
                const int sqlPrepareResult = sqlite3_prepare_v2(database, updateSql.UTF8String, -1, &statement, NULL);
                
                if(sqlPrepareResult != SQLITE_OK) {
                    SM_LOG_ERROR(@"could not prepare update text statement, error %d", sqlPrepareResult);
                    
                    [self triggerDBFailureWithSQLiteError:sqlPrepareResult];
                    break;
                }
                
                int dbQueryError = SQLITE_OK;
                
                do {
                    int bindResult;

                    if((bindResult = sqlite3_bind_text(statement, 1, plainTextBody.UTF8String, -1, NULL)) != SQLITE_OK) {
                        SM_LOG_ERROR(@"message UID %u, could not bind argument 4 (MESSAGEBODY), error %d", uid, bindResult);
                        
                        dbQueryFailed = YES;
                        dbQueryError = bindResult;
                        break;
                    }
                    
                    const int sqlUpdateResult = sqlite3_step(statement);
                    if(sqlUpdateResult == SQLITE_DONE) {
                        SM_LOG_DEBUG(@"Message text with UID %u successfully updated", uid);
                    } else {
                        SM_LOG_ERROR(@"Failed to updated message text body with UID %u, error %d", uid, sqlUpdateResult);
                        
                        dbQueryFailed = YES;
                        dbQueryError = sqlUpdateResult;
                        break;
                    }
                } while(FALSE);
                
                const int sqlFinalizeResult = sqlite3_finalize(statement);
                SM_LOG_NOISE(@"finalize messages insert statement result %d", sqlFinalizeResult);
                
                if(dbQueryFailed) {
                    SM_LOG_ERROR(@"SQL query has failed");
                    
                    [self triggerDBFailureWithSQLiteError:dbQueryError];
                    break;
                }
            } while(FALSE);

            //
            // Finalize the database.
            //
            [self closeDatabase:database];

            if(!dbQueryFailed) {
                [uidSet addObject:[NSNumber numberWithUnsignedInt:uid]];
            }
        }
        
        const int32_t newSerialQueueLen = OSAtomicAdd32(-1, &_serialQueueLength);
        SM_LOG_NOISE(@"serial queue length decreased: %d", newSerialQueueLen);
    });
}

- (NSData*)serializeMessageThread:(SMMessageThreadDescriptor*)messageThread {
    NSMutableData *serializedMessageThreadData = [NSMutableData dataWithCapacity:(messageThread.messagesCount * sizeof(uint32_t) * 2)];
    
    for(SMMessageThreadDescriptorEntry *message in messageThread.entries) {
        NSNumber *folderIdNum = [_folderIds objectForKey:message.folderName];
        if(folderIdNum == nil) {
            SM_LOG_ERROR(@"No id for folder \"%@\" found in DB", message.folderName);
            return nil;
        }
        
        const uint32_t folderId = [folderIdNum unsignedIntValue];
        const uint32_t uid = message.uid;
        
        [serializedMessageThreadData appendBytes:&folderId length:sizeof(folderId)];
        [serializedMessageThreadData appendBytes:&uid length:sizeof(uid)];
    }
    
    return serializedMessageThreadData;
}

- (SMMessageThreadDescriptor*)deserializeMessageThread:(uint64_t)threadId data:(NSData*)data {
    SMMessageThreadDescriptor *messageThreadDesc = [[SMMessageThreadDescriptor alloc] initWithMessageThreadId:threadId];
    
    uint32_t folderId = 0;
    uint32_t uid = 0;
    
    for(NSUInteger i = 0; i + (sizeof(folderId) + sizeof(uid)) <= data.length; i += (sizeof(folderId) + sizeof(uid))) {
        NSRange range;
        
        range.location = i;
        range.length = sizeof(folderId);
        
        [data getBytes:&folderId range:range];
        
        range.location = i + sizeof(folderId);
        range.length = sizeof(uid);
        
        [data getBytes:&uid range:range];
        
        NSString *folderName = [_folderNames objectForKey:[NSNumber numberWithUnsignedInt:folderId]];
        SMMessageThreadDescriptorEntry *entry = [[SMMessageThreadDescriptorEntry alloc] initWithFolderName:folderName uid:uid];
        
        [messageThreadDesc addEntry:entry];
    }
    
    return messageThreadDesc;
}

- (void)updateMessageThreadInDB:(SMMessageThreadDescriptor*)messageThread folder:(NSString*)folderName {
    const uint64_t messageThreadId = messageThread.threadId;
    
    if(messageThread.messagesCount <= 1) {
        [self removeMessageThreadFromDB:messageThreadId folder:folderName];
        return;
    }
    
    NSData *serializedMessageThread = [self serializeMessageThread:messageThread];
    if(serializedMessageThread == nil) {
        SM_LOG_ERROR(@"Could not serialize message thread (threadId %llu)", messageThreadId);
        
        // the only possible reason is that folders are unknown, which means 'critical data not found'
        [self triggerDBFailure:DBFailure_CriticalDataNotFound];
        return;
    }
    
    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_NOISE(@"serial queue length increased: %d", serialQueueLen);
    
    dispatch_async(_serialQueue, ^{
        [self runUrgentTasks];

        sqlite3 *database = [self openDatabase:DBOpenMode_ReadWrite];
        
        if(database != nil) {
            do {
                NSNumber *folderId = [_folderIds objectForKey:folderName];
                if(folderId == nil) {
                    SM_LOG_ERROR(@"No id for folder \"%@\" found in DB", folderName);

                    [self triggerDBFailure:DBFailure_CriticalDataNotFound];
                    break;
                }
                
                //
                // Step 1: check if this message thread already exists in the DB.
                //
                NSString *selectSql = [NSString stringWithFormat:@"SELECT UIDARRAY FROM MESSAGETHREADS WHERE THREADID = %llu AND FOLDERID = %@", messageThreadId, folderId];
                
                sqlite3_stmt *selectStatement = NULL;
                const int sqlSelectPrepareResult = sqlite3_prepare_v2(database, selectSql.UTF8String, -1, &selectStatement, NULL);
                
                if(sqlSelectPrepareResult != SQLITE_OK) {
                    SM_LOG_ERROR(@"could not prepare select statement, error %d", sqlSelectPrepareResult);

                    [self triggerDBFailureWithSQLiteError:sqlSelectPrepareResult];
                    break;
                }
                
                BOOL dbQueryFailed = NO;
                int dbQueryError = SQLITE_OK;
                
                const int sqlSelectStepResult = sqlite3_step(selectStatement);
                if(sqlSelectStepResult == SQLITE_ROW) {
                    //
                    // Step 2a: As there's already some data, just update it.
                    //
                    NSString *updateSql = [NSString stringWithFormat:@"UPDATE MESSAGETHREADS SET UIDARRAY = ? WHERE THREADID = %llu AND FOLDERID = %@", messageThreadId, folderId];
                    
                    sqlite3_stmt *statement = NULL;
                    const int sqlPrepareResult = sqlite3_prepare_v2(database, updateSql.UTF8String, -1, &statement, NULL);
                    
                    if(sqlPrepareResult != SQLITE_OK) {
                        SM_LOG_ERROR(@"could not prepare update statement, error %d", sqlPrepareResult);

                        [self triggerDBFailure:sqlPrepareResult];
                        break;
                    }
                    
                    do {
                        int bindResult = sqlite3_bind_blob(statement, 1, serializedMessageThread.bytes, (int)serializedMessageThread.length, SQLITE_STATIC);
                        if(bindResult != SQLITE_OK) {
                            SM_LOG_ERROR(@"message thread %llu, could not bind argument 1 (UIDARRAY), error %d", messageThreadId, bindResult);
                            
                            dbQueryFailed = YES;
                            dbQueryError = bindResult;
                            break;
                        }
                        
                        const int sqlUpdateResult = sqlite3_step(statement);
                        if(sqlUpdateResult == SQLITE_DONE) {
                            SM_LOG_DEBUG(@"message thread %llu successfully updated", messageThreadId);
                        }
                        else {
                            SM_LOG_ERROR(@"failed to update message thread %llu, error %d", messageThreadId, sqlUpdateResult);
                            
                            dbQueryFailed = YES;
                            dbQueryError = sqlUpdateResult;
                            break;
                        }
                    } while(FALSE);
                    
                    const int sqlFinalizeResult = sqlite3_finalize(statement);
                    SM_LOG_NOISE(@"finalize messages update statement result %d", sqlFinalizeResult);
                }
                else if(sqlSelectStepResult == SQLITE_DONE) {
                    //
                    // Step 2b: Existing message thread not found, insert the new data.
                    //
                    NSString *insertSql = @"INSERT INTO MESSAGETHREADS (\"THREADID\", \"FOLDERID\", \"UIDARRAY\") VALUES (?, ?, ?)";
                    
                    sqlite3_stmt *statement = NULL;
                    const int sqlPrepareResult = sqlite3_prepare_v2(database, insertSql.UTF8String, -1, &statement, NULL);
                    
                    if(sqlPrepareResult != SQLITE_OK) {
                        SM_LOG_ERROR(@"could not prepare insert statement, error %d", sqlPrepareResult);
                        
                        [self triggerDBFailureWithSQLiteError:sqlPrepareResult];
                        break;
                    }
                    
                    do {
                        int bindResult;
                        if((bindResult = sqlite3_bind_int64(statement, 1, messageThreadId)) != SQLITE_OK) {
                            SM_LOG_ERROR(@"message thread %llu, folder %@, could not bind argument 1 (THREADID), error %d", messageThreadId, folderId, bindResult);

                            dbQueryFailed = YES;
                            dbQueryError = bindResult;
                            break;
                        }
                        
                        if((bindResult = sqlite3_bind_int(statement, 2, [folderId unsignedIntValue])) != SQLITE_OK) {
                            SM_LOG_ERROR(@"message thread %llu, folder %@, could not bind argument 2 (FOLDERID), error %d", messageThreadId, folderId, bindResult);

                            dbQueryFailed = YES;
                            dbQueryError = bindResult;
                            break;
                        }
                        
                        if((bindResult = sqlite3_bind_blob(statement, 3, serializedMessageThread.bytes, (int)serializedMessageThread.length, SQLITE_STATIC)) != SQLITE_OK) {
                            SM_LOG_ERROR(@"message thread %llu, folder %@, could not bind argument 3 (UIDARRAY), error %d", messageThreadId, folderId, bindResult);

                            dbQueryFailed = YES;
                            dbQueryError = bindResult;
                            break;
                        }
                        
                        const int sqlInsertResult = sqlite3_step(statement);
                        if(sqlInsertResult == SQLITE_DONE) {
                            SM_LOG_DEBUG(@"message thread %llu successfully inserted for folder %@", messageThreadId, folderId);
                        } else if(sqlInsertResult == SQLITE_CONSTRAINT) {
                            SM_LOG_ERROR(@"message thread %llu already exists in folder %@ in the database", messageThreadId, folderId);

                            dbQueryFailed = YES;
                            dbQueryError = sqlInsertResult;
                            break;
                        } else {
                            SM_LOG_ERROR(@"failed to insert message thread %llu into folder %@, error %d", messageThreadId, folderId, sqlInsertResult);

                            dbQueryFailed = YES;
                            dbQueryError = sqlInsertResult;
                            break;
                        }
                    } while(FALSE);
                    
                    const int sqlFinalizeResult = sqlite3_finalize(statement);
                    SM_LOG_NOISE(@"finalize messages insert statement result %d", sqlFinalizeResult);
                }
                else {
                    SM_LOG_ERROR(@"failed to select message thread %llu, error %d", messageThreadId, sqlSelectStepResult);
                    
                    dbQueryFailed = YES;
                    dbQueryError = sqlSelectStepResult;
                }
                
                const int sqlFinalizeResult = sqlite3_finalize(selectStatement);
                SM_LOG_NOISE(@"finalize messages select statement result %d", sqlFinalizeResult);

                if(dbQueryFailed) {
                    SM_LOG_ERROR(@"SQL query has failed");
                    
                    [self triggerDBFailure:sqlSelectStepResult];
                    break;
                }
            } while(FALSE);
            
            [self closeDatabase:database];
        }
        
        const int32_t newSerialQueueLen = OSAtomicAdd32(-1, &_serialQueueLength);
        SM_LOG_NOISE(@"serial queue length decreased: %d", newSerialQueueLen);
    });
}

- (void)removeMessageThreadFromDB:(uint64_t)messageThreadId folder:(NSString*)folderName {
    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_NOISE(@"serial queue length increased: %d", serialQueueLen);
    
    dispatch_async(_serialQueue, ^{
        [self runUrgentTasks];

        sqlite3 *database = [self openDatabase:DBOpenMode_ReadWrite];
        
        if(database != nil) {
            do {
                NSNumber *folderId = [_folderIds objectForKey:folderName];
                if(folderId == nil) {
                    SM_LOG_ERROR(@"No id for folder \"%@\" found in DB", folderName);

                    [self triggerDBFailure:DBFailure_CriticalDataNotFound];
                    break;
                }
                
                NSString *insertSql = [NSString stringWithFormat:@"DELETE FROM MESSAGETHREADS WHERE THREADID = %llu AND FOLDERID = %@", messageThreadId, folderId];
                
                sqlite3_stmt *statement = NULL;
                const int sqlPrepareResult = sqlite3_prepare_v2(database, insertSql.UTF8String, -1, &statement, NULL);
                
                if(sqlPrepareResult != SQLITE_OK) {
                    SM_LOG_ERROR(@"could not prepare remove statement, error %d", sqlPrepareResult);

                    [self triggerDBFailureWithSQLiteError:sqlPrepareResult];
                    break;
                }

                BOOL dbQueryFailed = NO;
                
                const int sqlRemoveResult = sqlite3_step(statement);
                if(sqlRemoveResult == SQLITE_DONE) {
                    SM_LOG_DEBUG(@"message thread %llu successfully removed from folder %@", messageThreadId, folderId);
                } else {
                    SM_LOG_ERROR(@"failed to remove message thread %llu from folder %@, error %d", messageThreadId, folderId, sqlRemoveResult);

                    dbQueryFailed = YES;
                }
                
                const int sqlFinalizeResult = sqlite3_finalize(statement);
                SM_LOG_NOISE(@"finalize messages insert statement result %d", sqlFinalizeResult);
                
                if(dbQueryFailed) {
                    SM_LOG_ERROR(@"SQL query has failed");
                    
                    [self triggerDBFailure:sqlRemoveResult];
                    break;
                }
            } while(FALSE);
            
            [self closeDatabase:database];
        }
        
        const int32_t newSerialQueueLen = OSAtomicAdd32(-1, &_serialQueueLength);
        SM_LOG_NOISE(@"serial queue length decreased: %d", newSerialQueueLen);
    });
}

- (SMDatabaseOp*)loadMessageThreadFromDB:(uint64_t)messageThreadId folder:(NSString*)folderName block:(void (^)(SMMessageThreadDescriptor*))getMessageThreadBlock {
    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_NOISE(@"serial queue length increased: %d", serialQueueLen);
    
    SMDatabaseOp *dbOp = [[SMDatabaseOp alloc] init];
    
    dispatch_async(_serialQueue, ^{
        [self runUrgentTasks];

        if(dbOp.cancelled) {
            SM_LOG_DEBUG(@"DB op was cancelled");
            return;
        }

        SMMessageThreadDescriptor *messageThreadDesc = nil;
        
        sqlite3 *database = [self openDatabase:DBOpenMode_Read];
        
        if(database != nil) {
            do {
                NSNumber *folderId = [_folderIds objectForKey:folderName];
                if(folderId == nil) {
                    SM_LOG_ERROR(@"No id for folder \"%@\" found in DB", folderName);

                    [self triggerDBFailure:DBFailure_CriticalDataNotFound];
                    break;
                }
                
                NSString *insertSql = [NSString stringWithFormat:@"SELECT UIDARRAY FROM MESSAGETHREADS WHERE THREADID = %llu AND FOLDERID = %@", messageThreadId, folderId];
                
                sqlite3_stmt *statement = NULL;
                const int sqlPrepareResult = sqlite3_prepare_v2(database, insertSql.UTF8String, -1, &statement, NULL);
                
                if(sqlPrepareResult != SQLITE_OK) {
                    SM_LOG_ERROR(@"could not prepare remove statement, error %d", sqlPrepareResult);

                    [self triggerDBFailureWithSQLiteError:sqlPrepareResult];
                    break;
                }
                
                BOOL dbQueryFailed = NO;
                int dbQueryError = SQLITE_OK;
                
                do {
                    const int sqlLoadResult = sqlite3_step(statement);
                    if(sqlLoadResult == SQLITE_ROW) {
                        int dataSize = sqlite3_column_bytes(statement, 0);
                        NSData *data = [NSData dataWithBytesNoCopy:(void *)sqlite3_column_blob(statement, 0) length:dataSize freeWhenDone:NO];
                        
                        messageThreadDesc = [self deserializeMessageThread:messageThreadId data:data];
                        if(messageThreadDesc == nil) {
                            SM_LOG_ERROR(@"could not deserialize message thread %llu", messageThreadId);
                            
                            dbQueryFailed = YES;
                            break;
                        }
                    
                        SM_LOG_DEBUG(@"message thread %llu loaded from folder %@, messages count %lu", messageThreadId, folderId, messageThreadDesc.messagesCount);
                    }
                    else if(sqlLoadResult == SQLITE_DONE) {
                        SM_LOG_DEBUG(@"message thread %llu not found in folder %@ in the database", messageThreadId, folderId);
                    }
                    else {
                        SM_LOG_ERROR(@"failed to load message thread %llu, folder %@, error %d", messageThreadId, folderId, sqlLoadResult);

                        dbQueryFailed = YES;
                        dbQueryError = sqlLoadResult;
                        break;
                    }
                } while(FALSE);
                
                const int sqlFinalizeResult = sqlite3_finalize(statement);
                SM_LOG_NOISE(@"finalize messages insert statement result %d", sqlFinalizeResult);
                
                if(dbQueryFailed) {
                    SM_LOG_ERROR(@"SQL query has failed");
                    
                    if(dbQueryError != SQLITE_OK) {
                        [self triggerDBFailureWithSQLiteError:dbQueryError];
                    }
                    else {
                        [self triggerDBFailure:DBFailure_CriticalDataNotFound];
                    }
                    
                    break;
                }
            } while(FALSE);
            
            [self closeDatabase:database];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if(dbOp.cancelled) {
                SM_LOG_DEBUG(@"DB op was cancelled");
                return;
            }
            
            getMessageThreadBlock(messageThreadDesc);
        });
        
        const int32_t newSerialQueueLen = OSAtomicAdd32(-1, &_serialQueueLength);
        SM_LOG_NOISE(@"serial queue length decreased: %d", newSerialQueueLen);
    });
    
    return dbOp;
}

- (void)runUrgentTasks {
    while(TRUE) {
        void (^op)() = [_urgentTaskQueue popFrontOperation];
        
        if(op == nil) {
            SM_LOG_NOISE(@"no urgent operations to run");
            break;
        }
        
        SM_LOG_DEBUG(@"running urgent operation");
        
        op();
        
        SM_LOG_DEBUG(@"urgent operation has finished");
    }
}

- (void)dispatchOp:(void (^)())op urgent:(BOOL)urgent {
    if(urgent) {
        [_urgentTaskQueue pushBackOperation:op];
        
        // now run an "generic" urgent op handler just in case if the serial queue is empty
        // just to ensure that the urgent task will be executed as soon as possible
        // in any case
        dispatch_async(_serialQueue, ^{
            [self runUrgentTasks];
        });
    }
    else {
        const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
        SM_LOG_NOISE(@"serial queue length increased: %d", serialQueueLen);
        
        dispatch_async(_serialQueue, op);
    }
}

@end
