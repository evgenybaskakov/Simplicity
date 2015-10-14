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
#import "SMFolderDesc.h"
#import "SMMessageThreadDescriptor.h"
#import "SMMessageThreadDescriptorEntry.h"
#import "SMCompression.h"
#import "SMDatabase.h"

typedef NS_ENUM(NSInteger, DBFailureKind) {
    DBFailure_NonCriticalDataNotFound,
    DBFailure_CriticalDataNotFound,
    DBFailure_LibraryCriticalError,
    DBFailure_Busy,
    DBFailure_WriteError
};

@implementation SMDatabase {
    NSString *_dbFilePath;
    dispatch_queue_t _serialQueue;
    dispatch_queue_t _concurrentQueue;
    int32_t _serialQueueLength;
    int _nextFolderId;
    NSMutableDictionary *_folderIds;
    NSMutableDictionary *_folderNames;
    NSMutableDictionary *_messagesWithBodies;
    BOOL _dbInvalid;
    BOOL _dbMustBeReset;
}

- (id)initWithFilePath:(NSString*)dbFilePath {
    self = [self init];
    
    if(self) {
        _serialQueue = dispatch_queue_create("com.simplicity.Simplicity.serialDatabaseQueue", DISPATCH_QUEUE_SERIAL);
        _concurrentQueue = dispatch_queue_create("com.simplicity.Simplicity.concurrentDatabaseQueue", DISPATCH_QUEUE_CONCURRENT);
        _messagesWithBodies = [NSMutableDictionary dictionary];
        _dbFilePath = dbFilePath;
        
        [self checkDatabase];
        [self initDatabase];
        
        if(_dbInvalid) {
            [self resetDatabase];
            [self initDatabase];
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

- (sqlite3*)openDatabase {
    if(_dbMustBeReset) {
        // A previous database operation has failed; the DB is inconsistent.
        // So just drop and re-initialize it.
        [self resetDatabase];
        
        // Do not use the database afterwards, as it should be re-initialized
        // with the full application data on startup.
        _dbInvalid = YES;
        return nil;
    }
    
    if(_dbInvalid) {
        // Database is invalid, so just drop every operation.
        return nil;
    }
    
    sqlite3 *database = nil;
    
    const int openDatabaseResult = sqlite3_open(_dbFilePath.UTF8String, &database);
    if(openDatabaseResult == SQLITE_OK) {
        SM_LOG_DEBUG(@"Database %@ open successfully", _dbFilePath);
        return database;
    }
    else {
        SM_LOG_FATAL(@"Database %@ cannot be open", _dbFilePath);
        return nil;
    }
}

- (void)closeDatabase:(sqlite3*)database {
    const int sqlCloseResult = sqlite3_close(database);
    
    if(sqlCloseResult != SQLITE_OK) {
        SM_LOG_ERROR(@"could not close database, error %d", sqlCloseResult);
    }
}

- (void)checkDatabase {
    BOOL databaseValid = NO;
    
    sqlite3 *const database = [self openDatabase];
    if(database != nil) {
        char *errMsg = NULL;
        const char *checkStmt = "PRAGMA QUICK_CHECK";
        
        const int sqlResult = sqlite3_exec(database, checkStmt, NULL, NULL, &errMsg);
        if(sqlResult == SQLITE_OK) {
            SM_LOG_DEBUG(@"Database '%@' check successful.", _dbFilePath);
            
            databaseValid = YES;
        }
        else {
            SM_LOG_ERROR(@"Database '%@' check failed: %s (error %d). Database will be erased and created from ground.", _dbFilePath, errMsg, sqlResult);
        }
        
        [self closeDatabase:database];
    }
    
    if(!databaseValid) {
        SM_LOG_ERROR(@"Database '%@' is inconsistent and will be reset.", _dbFilePath);
        
        [self resetDatabase];
    }
    else {
        SM_LOG_INFO(@"Database '%@' is consistent.", _dbFilePath);
    }
}

- (void)resetDatabase {
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:_dbFilePath error:&error];
    
    if(error != nil && error.code != NSFileNoSuchFileError) {
        SM_LOG_ERROR(@"Cannot remove database file '%@': %@", _dbFilePath, error);
        
        _dbInvalid = YES;
    }
    else {
        SM_LOG_INFO(@"Database '%@' has been erased as inconsistent.", _dbFilePath);
        
        _dbInvalid = NO;
    }
    
    _dbMustBeReset = NO;
}

- (void)initDatabase {
    BOOL initSuccessful = NO;
    
    sqlite3 *const database = [self openDatabase];
    
    if(database != nil) {
        if([self createFoldersTable:database]) {
            if([self createMessageThreadsTable:database]) {
                if([self loadFolderIds:database]) {
                    SM_LOG_INFO(@"Database initialized successfully");
                    
                    initSuccessful = YES;
                } else {
                    SM_LOG_ERROR(@"Failed to load folder ids");
                }
            }
            else {
                SM_LOG_ERROR(@"Failed to init message thread table");
            }
        }
        else {
            SM_LOG_ERROR(@"Failed to init folder table");
        }
        
        [self closeDatabase:database];
    }
    else {
        SM_LOG_ERROR(@"Cannot open database file '%@'. Database will be reset.", _dbFilePath);
    }
    
    if(initSuccessful) {
        _dbInvalid = NO;
    }
    else {
        _dbInvalid = YES;
    }
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
    const int generatedFolderId = [self generateFolderId];
    NSNumber *folderId = [NSNumber numberWithInt:generatedFolderId];
    
    [_folderIds setObject:folderId forKey:folderName];
    [_folderNames setObject:folderName forKey:folderId];
    
    [_messagesWithBodies setObject:[NSMutableSet set] forKey:folderId];
    
    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_DEBUG(@"serial queue length: %d", serialQueueLen);
    
    dispatch_async(_serialQueue, ^{
        sqlite3 *database = [self openDatabase];
        
        if(database != nil) {
            do {
                //
                // Step 1: Add the folder into the DB.
                //
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
                int dbQueryFailureError = SQLITE_OK;
                
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
                    
                        dbQueryFailureError = sqlResult;
                        dbQueryFailed = YES;
                        break;
                    }
                } while(FALSE);
                
                const int sqlFinalizeResult = sqlite3_finalize(statement);
                SM_LOG_NOISE(@"finalize folders insert statement result %d", sqlFinalizeResult);

                if(dbQueryFailed) {
                    SM_LOG_ERROR(@"database query failed");
                    
                    [self triggerDBFailureWithSQLiteError:dbQueryFailureError];
                    break;
                }
                
                //
                // Step 2: Create a unique folder table containing message UIDs.
                //
                NSString *createMessageTableSql = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS FOLDER%@ (UID INTEGER PRIMARY KEY UNIQUE, MESSAGE BLOB)", folderId];
                const char *createMessageTableStmt = [createMessageTableSql UTF8String];
                
                char *errMsg = NULL;
                const int sqlMessageTableResult = sqlite3_exec(database, createMessageTableStmt, NULL, NULL, &errMsg);
                if(sqlMessageTableResult != SQLITE_OK) {
                    SM_LOG_ERROR(@"Failed to create table for folder id %@: %s, error %d", folderId, errMsg, sqlMessageTableResult);

                    [self triggerDBFailureWithSQLiteError:sqlMessageTableResult];
                    break;
                }
                
                //
                // Step 2: Create a unique folder table containing message bodies.
                //
                NSString *createBodiesTableSql = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS MESSAGEBODIES%@ (UID INTEGER PRIMARY KEY UNIQUE, MESSAGEBODY BLOB)", folderId];
                const char *createStmt = [createBodiesTableSql UTF8String];
                
                const int sqlBodiesTableResult = sqlite3_exec(database, createStmt, NULL, NULL, NULL);
                if(sqlBodiesTableResult != SQLITE_OK) {
                    SM_LOG_ERROR(@"Failed to create table MESSAGEBODIES%@: error %d", folderId, sqlBodiesTableResult);

                    [self triggerDBFailureWithSQLiteError:sqlBodiesTableResult];
                    break;
                }
            } while(FALSE);
            
            [self closeDatabase:database];
        }
        
        OSAtomicAdd32(-1, &_serialQueueLength);
    });
}

- (void)renameDBFolder:(NSString*)folderName newName:(NSString*)newName {
    NSAssert(nil, @"TODO");
}

- (void)removeDBFolder:(NSString*)folderName {
    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_DEBUG(@"serial queue length: %d", serialQueueLen);
    
    dispatch_async(_serialQueue, ^{
        sqlite3 *database = [self openDatabase];
        
        if(database != nil) {
            do {
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
            } while(FALSE);
            
            [self closeDatabase:database];
        }
        
        OSAtomicAdd32(-1, &_serialQueueLength);
    });
}

- (void)loadDBFolders:(void (^)(NSArray*))loadFoldersBlock {
    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_DEBUG(@"serial queue length: %d", serialQueueLen);
    
    dispatch_async(_serialQueue, ^{
        sqlite3 *database = [self openDatabase];
        
        if(database != nil) {
            NSMutableArray *folders = nil;
            
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
            
            dispatch_async(dispatch_get_main_queue(), ^{
                loadFoldersBlock(folders);
            });
        }
        
        OSAtomicAdd32(-1, &_serialQueueLength);
    });
}

- (void)getMessagesCountInDBFolder:(NSString*)folderName block:(void (^)(NSUInteger))getMessagesCountBlock {
    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_DEBUG(@"serial queue length: %d", serialQueueLen);
    
    dispatch_async(_serialQueue, ^{
        sqlite3 *database = [self openDatabase];
        
        if(database != nil) {
            NSUInteger messagesCount = 0;
            
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
            
            dispatch_async(dispatch_get_main_queue(), ^{
                getMessagesCountBlock(messagesCount);
            });
        }
        
        OSAtomicAdd32(-1, &_serialQueueLength);
    });
}

- (void)loadMessageHeadersFromDBFolder:(NSString*)folderName offset:(NSUInteger)offset count:(NSUInteger)count block:(void (^)(NSArray*))getMessagesBlock {
    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_DEBUG(@"serial queue length: %d", serialQueueLen);
    
    dispatch_async(_serialQueue, ^{
        sqlite3 *database = [self openDatabase];
        
        if(database != nil) {
            NSMutableArray *messages = [NSMutableArray arrayWithCapacity:count];
            
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
                        
                        MCOIMAPMessage *message = [NSKeyedUnarchiver unarchiveObjectWithData:uncompressedData];
                        if(message == nil) {
                            SM_LOG_ERROR(@"could not decode IMAP message");
                            
                            dbQueryFailed = YES;
                            break;
                        }
                        
                        [messages addObject:message];
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
            
            dispatch_async(dispatch_get_main_queue(), ^{
                getMessagesBlock(messages);
            });
        }
        
        OSAtomicAdd32(-1, &_serialQueueLength);
    });
}

- (void)loadMessageHeaderForUIDFromDBFolder:(NSString*)folderName uid:(uint32_t)uid block:(void (^)(MCOIMAPMessage*))getMessageBlock {
    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_DEBUG(@"serial queue length: %d", serialQueueLen);
    
    dispatch_async(_serialQueue, ^{
        sqlite3 *database = [self openDatabase];
        
        if(database != nil) {
            MCOIMAPMessage *message = nil;
            
            do {
                NSNumber *folderId = [_folderIds objectForKey:folderName];
                if(folderId == nil) {
                    SM_LOG_ERROR(@"No id for folder \"%@\" found in DB", folderName);

                    [self triggerDBFailure:DBFailure_CriticalDataNotFound];
                    break;
                }
                
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
                    
                    break;
                }
            } while(FALSE);
            
            [self closeDatabase:database];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                getMessageBlock(message);
            });
        }
        
        OSAtomicAdd32(-1, &_serialQueueLength);
    });
}

- (BOOL)loadMessageBodyForUIDFromDB:(uint32_t)uid folderName:(NSString*)folderName urgent:(BOOL)urgent block:(void (^)(NSData*, MCOMessageParser*, NSArray*))getMessageBodyBlock {
    NSNumber *folderId = [_folderIds objectForKey:folderName];
    if(folderId == nil) {
        SM_LOG_ERROR(@"No id for folder \"%@\" found in DB", folderName);
        return FALSE;
    }
    
    NSSet *uidSet = [_messagesWithBodies objectForKey:folderId];
    if(uidSet == nil) {
        SM_LOG_WARNING(@"folder '%@' (%@) is unknown", folderName, folderId);
        return FALSE;
    }
    
    if(![uidSet containsObject:[NSNumber numberWithUnsignedInt:uid]]) {
        SM_LOG_NOISE(@"no message body for message UID %u in the database", uid);
        return FALSE;
    }
    
    SM_LOG_NOISE(@"message UID %u has its body in the database", uid);
    
    // Depending on the user requested urgency, we either select the
    // serial (FIFO) queue, or the concurrent one. In case of concurrent,
    // it won't have to wait while other non-urgent requests are processed.
    // Note that there may be heavy requests, so the serial
    // queue cannot be trusted in terms of response time.
    dispatch_async(urgent? _concurrentQueue : _serialQueue, ^{
        sqlite3 *database = [self openDatabase];
        
        if(database != nil) {
            NSString *getMessageBodySql = [NSString stringWithFormat:@"SELECT MESSAGEBODY FROM MESSAGEBODIES%@ WHERE UID = \"%u\"", folderId, uid];
            
            sqlite3_stmt *statement = NULL;
            const int sqlPrepareResult = sqlite3_prepare_v2(database, [getMessageBodySql UTF8String], -1, &statement, NULL);
            
            NSData *messageBody = nil;
            
            if(sqlPrepareResult == SQLITE_OK) {
                const int sqlStepResult = sqlite3_step(statement);
                
                if(sqlStepResult == SQLITE_ROW) {
                    int dataSize = sqlite3_column_bytes(statement, 0);
                    NSData *data = [NSData dataWithBytesNoCopy:(void *)sqlite3_column_blob(statement, 0) length:dataSize freeWhenDone:NO];
                    NSData *uncompressedData = [SMCompression gzipInflate:data];
                    
                    messageBody = uncompressedData;
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
            
            MCOMessageParser *parser = (messageBody != nil? [MCOMessageParser messageParserWithData:messageBody] : nil);
            NSArray *attachments = (messageBody != nil? parser.attachments : nil); // note that this is potentially long operation, so do it in the current thread, not in the main thread
            
            dispatch_async(dispatch_get_main_queue(), ^{
                getMessageBodyBlock(messageBody, parser, attachments);
            });
        }
    });
    
    return TRUE;
}

- (NSData*)encodeImapMessage:(MCOIMAPMessage*)imapMessage {
    NSData *encodedMessage = [NSKeyedArchiver archivedDataWithRootObject:imapMessage];
    NSAssert(encodedMessage != nil, @"could not encode IMAP message");
    
    NSData *compressedMessage = [SMCompression gzipDeflate:encodedMessage];
    
    SM_LOG_DEBUG(@"message UID %u, data len %lu, compressed len %lu (%lu%% from original)", imapMessage.uid, encodedMessage.length, compressedMessage.length, compressedMessage.length/(encodedMessage.length/100));
    
    return compressedMessage;
}

- (void)putMessageToDBFolder:(MCOIMAPMessage*)imapMessage folder:(NSString*)folderName {
    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_DEBUG(@"serial queue length: %d", serialQueueLen);
    
    dispatch_async(_serialQueue, ^{
        sqlite3 *database = [self openDatabase];
        
        if(database != nil) {
            do {
                NSNumber *folderId = [_folderIds objectForKey:folderName];
                if(folderId == nil) {
                    SM_LOG_ERROR(@"No id for folder \"%@\" found in DB", folderName);
                    
                    [self triggerDBFailure:DBFailure_CriticalDataNotFound];
                    break;
                }
                
                NSString *folderInsertSql = [NSString stringWithFormat:@"INSERT INTO FOLDER%@ (\"UID\", \"MESSAGE\") VALUES (?, ?)", folderId];
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
                    if((bindResult = sqlite3_bind_int(statement, 1, imapMessage.uid)) != SQLITE_OK) {
                        SM_LOG_ERROR(@"message UID %u, could not bind argument 1 (UID), error %d", imapMessage.uid, bindResult);
                        
                        dbQueryFailed = YES;
                        dbQueryError = bindResult;
                        break;
                    }
                    
                    NSData *encodedMessage = [self encodeImapMessage:imapMessage];
                    
                    if((bindResult = sqlite3_bind_blob(statement, 2, encodedMessage.bytes, (int)encodedMessage.length, SQLITE_STATIC)) != SQLITE_OK) {
                        SM_LOG_ERROR(@"message UID %u, could not bind argument 2 (MESSAGE), error %d", imapMessage.uid, bindResult);
                        
                        dbQueryFailed = YES;
                        dbQueryError = bindResult;
                        break;
                    }
                    
                    const int sqlStepResult = sqlite3_step(statement);
                    
                    if(sqlStepResult != SQLITE_DONE) {
                        if(sqlStepResult == SQLITE_CONSTRAINT) {
                            // TODO: This happened once. How could it happen?..
                            SM_LOG_ERROR(@"Message with UID %u already in folder \"%@\" (id %@)", imapMessage.uid, folderName, folderId);
                        }
                        else {
                            SM_LOG_ERROR(@"Failed to insert message with UID %u in folder \"%@\" (id %@), error %d", imapMessage.uid, folderName, folderId, sqlStepResult);
                        }
                        
                        dbQueryFailed = YES;
                        dbQueryError = sqlStepResult;
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
                
                SM_LOG_DEBUG(@"Message with UID %u successfully inserted to folder \"%@\" (id %@)", imapMessage.uid, folderName, folderId);
            } while(FALSE);
            
            [self closeDatabase:database];
        }
        
        OSAtomicAdd32(-1, &_serialQueueLength);
    });
}

- (void)updateMessageInDBFolder:(MCOIMAPMessage*)imapMessage folder:(NSString*)folderName {
    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_DEBUG(@"serial queue length: %d", serialQueueLen);
    
    dispatch_async(_serialQueue, ^{
        sqlite3 *database = [self openDatabase];
        
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
        
        OSAtomicAdd32(-1, &_serialQueueLength);
    });
}

- (void)removeMessageFromDBFolder:(uint32_t)uid folder:(NSString*)folderName {
    NSNumber *folderId = [_folderIds objectForKey:folderName];
    if(folderId == nil) {
        SM_LOG_ERROR(@"No id for folder \"%@\" found in DB", folderName);
        return;
    }
    
    NSMutableSet *uidSet = [_messagesWithBodies objectForKey:folderId];
    if(uidSet == nil) {
        SM_LOG_WARNING(@"folder '%@' (%@) is unknown", folderName, folderId);
        return;
    }
    
    [uidSet removeObject:[NSNumber numberWithUnsignedInt:uid]];
    
    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_DEBUG(@"serial queue length: %d", serialQueueLen);
    
    dispatch_async(_serialQueue, ^{
        sqlite3 *database = [self openDatabase];
        
        if(database != nil) {
            do {
                //
                // Step 1: Remove message UID from the folder table.
                //
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
                    SM_LOG_NOISE(@"finalize folders remove statement result %d", sqlFinalizeResult);
                }
            } while(FALSE);
            
            [self closeDatabase:database];
        }
        
        OSAtomicAdd32(-1, &_serialQueueLength);
    });
}

- (void)putMessageBodyToDB:(uint32_t)uid data:(NSData*)data folderName:(NSString*)folderName {
    NSNumber *folderId = [_folderIds objectForKey:folderName];
    if(folderId == nil) {
        SM_LOG_ERROR(@"No id for folder \"%@\" found in DB", folderName);

        [self triggerDBFailure:DBFailure_CriticalDataNotFound];
        return;
    }
    
    NSMutableSet *uidSet = [_messagesWithBodies objectForKey:folderId];
    if(uidSet == nil) {
        SM_LOG_ERROR(@"folder '%@' (%@) is unknown", folderName, folderId);

        [self triggerDBFailure:DBFailure_CriticalDataNotFound];
        return;
    }
    
    if([uidSet containsObject:[NSNumber numberWithUnsignedInt:uid]]) {
        SM_LOG_DEBUG(@"message with UID %u (folder %@) already has its body in the database", uid, folderName);
        return;
    }
    
    [uidSet addObject:[NSNumber numberWithUnsignedInt:uid]];
    
    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_DEBUG(@"serial queue length: %d", serialQueueLen);
    
    dispatch_async(_serialQueue, ^{
        sqlite3 *database = [self openDatabase];
        
        if(database != nil) {
            do {
                NSString *insertSql = [NSString stringWithFormat:@"INSERT INTO MESSAGEBODIES%@ (\"UID\", \"MESSAGEBODY\") VALUES (?, ?)", folderId];
                
                sqlite3_stmt *statement = NULL;
                const int sqlPrepareResult = sqlite3_prepare_v2(database, insertSql.UTF8String, -1, &statement, NULL);
                
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
                    
                    NSData *compressedData = [SMCompression gzipDeflate:data];
                    NSAssert(compressedData != nil, @"compressed data is nil");
                    
                    SM_LOG_DEBUG(@"message UID %u, data len %lu, compressed len %lu (%lu%% from original)", uid, data.length, compressedData.length, compressedData.length/(data.length/100));
                    
                    if((bindResult = sqlite3_bind_blob(statement, 2, compressedData.bytes, (int)compressedData.length, SQLITE_STATIC)) != SQLITE_OK) {
                        SM_LOG_ERROR(@"message UID %u, could not bind argument 2 (MESSAGEBODY), error %d", uid, bindResult);
                        
                        dbQueryFailed = YES;
                        dbQueryError = bindResult;
                        break;
                    }
                    
                    const int sqlInsertResult = sqlite3_step(statement);
                    if(sqlInsertResult == SQLITE_DONE) {
                        SM_LOG_DEBUG(@"Message with UID %u successfully inserted", uid);
                    } else if(sqlInsertResult == SQLITE_CONSTRAINT) {
                        SM_LOG_INFO(@"Message with UID %u already exists", uid);
                    } else {
                        SM_LOG_ERROR(@"Failed to insert message with UID %u, error %d", uid, sqlInsertResult);
                        
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
        
        OSAtomicAdd32(-1, &_serialQueueLength);
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
    SM_LOG_DEBUG(@"serial queue length: %d", serialQueueLen);
    
    dispatch_async(_serialQueue, ^{
        sqlite3 *database = [self openDatabase];
        
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
        
        OSAtomicAdd32(-1, &_serialQueueLength);
    });
}

- (void)removeMessageThreadFromDB:(uint64_t)messageThreadId folder:(NSString*)folderName {
    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_DEBUG(@"serial queue length: %d", serialQueueLen);
    
    dispatch_async(_serialQueue, ^{
        sqlite3 *database = [self openDatabase];
        
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
        
        OSAtomicAdd32(-1, &_serialQueueLength);
    });
}

- (void)loadMessageThreadFromDB:(uint64_t)messageThreadId folder:(NSString*)folderName block:(void (^)(SMMessageThreadDescriptor*))getMessageThreadBlock {
    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_DEBUG(@"serial queue length: %d", serialQueueLen);
    
    dispatch_async(_serialQueue, ^{
        sqlite3 *database = [self openDatabase];
        
        if(database != nil) {
            SMMessageThreadDescriptor *messageThreadDesc = nil;
            
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
            
            dispatch_async(dispatch_get_main_queue(), ^{
                getMessageThreadBlock(messageThreadDesc);
            });
        }
        
        OSAtomicAdd32(-1, &_serialQueueLength);
    });
}

@end