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

@implementation SMDatabase {
    NSString *_dbFilePath;
    dispatch_queue_t _serialQueue;
    dispatch_queue_t _concurrentQueue;
    int32_t _serialQueueLength;
    int _nextFolderId;
    NSMutableDictionary *_folderIds;
    NSMutableDictionary *_folderNames;
    NSMutableDictionary *_messagesWithBodies;
}

- (id)initWithFilePath:(NSString*)dbFilePath {
    self = [self init];

    if(self) {
        _serialQueue = dispatch_queue_create("com.simplicity.Simplicity.serialDatabaseQueue", DISPATCH_QUEUE_SERIAL);
        _concurrentQueue = dispatch_queue_create("com.simplicity.Simplicity.concurrentDatabaseQueue", DISPATCH_QUEUE_CONCURRENT);
        _dbFilePath = dbFilePath;
        
        [self initDatabase];
    }
    
    return self;
}

- (sqlite3*)openDatabase {
    sqlite3 *database = nil;
    
    const int openDatabaseResult = sqlite3_open([_dbFilePath UTF8String], &database);
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

- (void)initDatabase {
    _messagesWithBodies = [NSMutableDictionary dictionary];
    
    sqlite3 *database = [self openDatabase];
    
    if(database != nil) {
        [self createFoldersTable:database];
        [self createMessageThreadsTable:database];
        [self loadFolderIds:database];
        [self closeDatabase:database];
    }
}

- (void)createMessageThreadsTable:(sqlite3*)database {
    char *errMsg = NULL;
    const char *createStmt = "CREATE TABLE IF NOT EXISTS MESSAGETHREADS (THREADID INTEGER PRIMARY KEY, UIDARRAY BLOB)";
    
    const int sqlResult = sqlite3_exec(database, createStmt, NULL, NULL, &errMsg);
    if(sqlResult != SQLITE_OK) {
        SM_LOG_ERROR(@"Failed to create table FOLDERS: %s, error %d", errMsg, sqlResult);
        // TODO: mark the DB as invalid?
    }
}

- (void)createFoldersTable:(sqlite3*)database {
    char *errMsg = NULL;
    const char *createStmt = "CREATE TABLE IF NOT EXISTS FOLDERS (ID INTEGER PRIMARY KEY, NAME TEXT UNIQUE, DELIMITER INTEGER, FLAGS INTEGER)";
    
    const int sqlResult = sqlite3_exec(database, createStmt, NULL, NULL, &errMsg);
    if(sqlResult != SQLITE_OK) {
        SM_LOG_ERROR(@"Failed to create table FOLDERS: %s, error %d", errMsg, sqlResult);
        // TODO: mark the DB as invalid?
    }
}

- (void)createFolderMessagesTable:(sqlite3*)database folderName:(NSString*)folderName {
    NSNumber *folderId = [_folderIds objectForKey:folderName];
    if(folderId == nil) {
        SM_LOG_ERROR(@"No id for folder \"%@\" found in DB", folderName);
        // TODO: mark the DB as invalid?
    }
    
    NSString *createSql = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS FOLDER%@ (UID INTEGER PRIMARY KEY UNIQUE, MESSAGE BLOB)", folderId];
    const char *createStmt = [createSql UTF8String];
    
    char *errMsg = NULL;
    const int sqlResult = sqlite3_exec(database, createStmt, NULL, NULL, &errMsg);
    if(sqlResult != SQLITE_OK) {
        SM_LOG_ERROR(@"Failed to create table for folder \"%@\" (id %@): %s, error %d", folderName, folderId, errMsg, sqlResult);
        // TODO: mark the DB as invalid?
    }
}

- (void)createMessageBodiesTable:(sqlite3*)database folderName:(NSString*)folderName {
    NSNumber *folderId = [_folderIds objectForKey:folderName];
    if(folderId == nil) {
        SM_LOG_ERROR(@"No id for folder \"%@\" found in DB", folderName);
        // TODO: mark the DB as invalid?
    }

    NSString *createSql = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS MESSAGEBODIES%@ (UID INTEGER PRIMARY KEY UNIQUE, MESSAGEBODY BLOB)", folderId];
    const char *createStmt = [createSql UTF8String];

    const int sqlResult = sqlite3_exec(database, createStmt, NULL, NULL, NULL);
    if(sqlResult != SQLITE_OK) {
        SM_LOG_ERROR(@"Failed to create table MESSAGEBODIES%@: error %d", folderId, sqlResult);
        // TODO: mark the DB as invalid?
    }
}

- (NSDictionary*)loadDataFromDB:(sqlite3*)database query:(const char *)sqlQuery {
    NSAssert(database != nil, @"no database open");
    
    sqlite3_stmt *statement = NULL;
    const int sqlPrepareResult = sqlite3_prepare_v2(database, sqlQuery, -1, &statement, NULL);
    if(sqlPrepareResult != SQLITE_OK) {
        SM_LOG_ERROR(@"could not prepare load statement, error %d", sqlPrepareResult);
    }
    
    NSMutableArray *arrRows = [[NSMutableArray alloc] init];
    NSMutableArray *arrColumnNames = [[NSMutableArray alloc] init];
    const int totalColumns = sqlite3_column_count(statement);
    
    while(sqlite3_step(statement) == SQLITE_ROW) {
        NSMutableArray *arrDataRow = [[NSMutableArray alloc] init];
        
        for(int i = 0; i < totalColumns; i++){
            char *dbDataAsChars = (char *)sqlite3_column_text(statement, i);
            
            if(dbDataAsChars != NULL) {
                [arrDataRow addObject:[NSString  stringWithUTF8String:dbDataAsChars]];
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

- (void)loadFolderIds:(sqlite3*)database {
    _folderIds = [[NSMutableDictionary alloc] init];
    _folderNames = [[NSMutableDictionary alloc] init];

    const char *sqlQuery = "SELECT * FROM FOLDERS";
    NSDictionary *foldersTable = [self loadDataFromDB:database query:sqlQuery];
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

            [_folderIds setObject:folderId forKey:nameStr];
            [_folderNames setObject:nameStr forKey:folderId];
            
            [self loadMessageBodiesInfo:database folderId:folderId];
            
            SM_LOG_DEBUG(@"Folder \"%@\" id %@", nameStr, folderId);
        }
    }
}

- (void)loadMessageBodiesInfo:(sqlite3*)database folderId:(NSNumber*)folderId {
    NSMutableSet *uidSet = [NSMutableSet set];

    NSString *getMessageBodySql = [NSString stringWithFormat:@"SELECT UID FROM MESSAGEBODIES%@", folderId];
    
    sqlite3_stmt *statement = NULL;
    const int sqlPrepareResult = sqlite3_prepare_v2(database, [getMessageBodySql UTF8String], -1, &statement, NULL);
    
    if(sqlPrepareResult == SQLITE_OK) {
        while(sqlite3_step(statement) == SQLITE_ROW) {
            uint32_t uid = sqlite3_column_int(statement, 0);
            
            SM_LOG_DEBUG(@"message with UID %u has its body in the database", uid);

            [uidSet addObject:[NSNumber numberWithUnsignedInt:uid]];
        }
    }
    else {
        SM_LOG_ERROR(@"could not prepare load statement, error %d", sqlPrepareResult);
        // TODO
    }
    
    const int sqlFinalizeResult = sqlite3_finalize(statement);
    SM_LOG_NOISE(@"finalize message count statement result %d", sqlFinalizeResult);

    [_messagesWithBodies setObject:uidSet forKey:folderId];
}

- (void)loadFolderId:(sqlite3*)database folderName:(NSString*)folderName {
    NSString *selectSql = [NSString stringWithFormat:@"SELECT ID FROM FOLDERS WHERE NAME = \"%@\"", folderName];
    NSDictionary *foldersTable = [self loadDataFromDB:database query:[selectSql UTF8String]];
    NSArray *columns = [foldersTable objectForKey:@"Columns"];
    NSArray *rows = [foldersTable objectForKey:@"Rows"];
    
    const NSInteger idColumn = [columns indexOfObject:@"ID"];
    
    if(idColumn != 0) {
        SM_LOG_ERROR(@"database corrupted: folder ID column not found (column value %ld)", idColumn);
        // TODO: trigger database erase
    }
    else if(rows.count != 1) {
        SM_LOG_ERROR(@"database corrupted: folder could not be added");
        // TODO: trigger database erase
    }
    else {
        NSArray *row = rows[0];
        NSString *idStr = row[0];
        NSUInteger folderIdNum = [idStr integerValue];
        NSNumber *folderId = [NSNumber numberWithUnsignedInteger:folderIdNum];
        
        [_folderIds setObject:folderId forKey:folderName];
        [_folderNames setObject:folderName forKey:folderId];
        
        SM_LOG_DEBUG(@"Folder \"%@\" id %@", folderName, folderId);
    }
}

- (int)generateFolderId {
    while([_folderIds objectForKey:[NSNumber numberWithInt:_nextFolderId]] != nil) {
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
            //
            // Step 1: Add the folder into the DB.
            //
            NSString *insertSql = [NSString stringWithFormat:@"INSERT INTO FOLDERS (ID, NAME, DELIMITER, FLAGS) VALUES (%@, \"%@\", %ld, %ld)", folderId, folderName, (NSInteger)delimiter, (NSInteger)flags];
            const char *insertStmt = [insertSql UTF8String];
            
            sqlite3_stmt *statement = NULL;
            const int sqlPrepareResult = sqlite3_prepare_v2(database, insertStmt, -1, &statement, NULL);
            if(sqlPrepareResult != SQLITE_OK) {
                SM_LOG_ERROR(@"could not prepare folders insert statement, error %d", sqlPrepareResult);
            }
            
            BOOL newFolderAdded = NO;
            
            const int sqlResult = sqlite3_step(statement);
            if(sqlResult == SQLITE_DONE) {
                SM_LOG_DEBUG(@"Folder %@ successfully inserted", folderName);

                newFolderAdded = YES;
            } else if(sqlResult == SQLITE_CONSTRAINT) {
                SM_LOG_ERROR(@"Folder %@ already exists", folderName);
            } else {
                SM_LOG_ERROR(@"Failed to insert folder %@, error %d", folderName, sqlResult);
            }
            
            const int sqlFinalizeResult = sqlite3_finalize(statement);
            SM_LOG_NOISE(@"finalize folders insert statement result %d", sqlFinalizeResult);

            if(newFolderAdded) {
                //
                // Step 2: For new folders, find out what's the ID of the newly added folder.
                //
                [self loadFolderId:database folderName:folderName];
                
                //
                // Step 3: Create a unique folder table containing message UIDs.
                //
                [self createFolderMessagesTable:database folderName:folderName];

                //
                // Step 4: Create a unique folder table containing message bodies.
                //
                [self createMessageBodiesTable:database folderName:folderName];
            }
            
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
            NSString *removeSql = [NSString stringWithFormat:@"DELETE FROM FOLDERS WHERE NAME = \"%@\"", folderName];
            const char *removeStmt = [removeSql UTF8String];

            sqlite3_stmt *statement = NULL;
            const int sqlPrepareResult = sqlite3_prepare_v2(database, removeStmt, -1, &statement, NULL);
            if(sqlPrepareResult != SQLITE_OK) {
                SM_LOG_ERROR(@"could not prepare folders remove statement, error %d", sqlPrepareResult);
            }
            
            int sqlResult = sqlite3_step(statement);
            if(sqlResult == SQLITE_DONE) {
                SM_LOG_INFO(@"Folder %@ successfully removed", folderName);
            } else {
                SM_LOG_ERROR(@"Failed to remove folder %@, error %d", folderName, sqlResult);
            }
            
            const int sqlFinalizeResult = sqlite3_finalize(statement);
            SM_LOG_NOISE(@"finalize folders remove statement result %d", sqlFinalizeResult);
         
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
                }
                
                // TODO: trigger database erase
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

            NSNumber *folderId = [_folderIds objectForKey:folderName];
            if(folderId != nil) {
                NSString *getCountSql = [NSString stringWithFormat:@"SELECT COUNT(*) FROM FOLDER%@", folderId];
                const char *getCountStmt = [getCountSql UTF8String];
                
                sqlite3_stmt *statement = NULL;
                const int sqlPrepareResult = sqlite3_prepare_v2(database, getCountStmt, -1, &statement, NULL);
                if(sqlPrepareResult == SQLITE_OK) {
                    int sqlResult = sqlite3_step(statement);
                    if(sqlResult == SQLITE_ROW) {
                        SM_LOG_DEBUG(@"Step for folder %@ is successful", folderName);
                        
                        messagesCount = sqlite3_column_int(statement, 0);

                        SM_LOG_DEBUG(@"Messages count in folder %@ is %lu", folderName, messagesCount);
                    } else {
                        SM_LOG_ERROR(@"Failed to get messages count from folder %@, error %d", folderName, sqlResult);
                    }
                }
                else {
                    SM_LOG_ERROR(@"could not prepare messages count statement, error %d", sqlPrepareResult);
                }
                
                const int sqlFinalizeResult = sqlite3_finalize(statement);
                SM_LOG_NOISE(@"finalize message count statement result %d", sqlFinalizeResult);
            }
            
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
            NSNumber *folderId = [_folderIds objectForKey:folderName];
            if(folderId == nil) {
                SM_LOG_ERROR(@"No id for folder \"%@\" found in DB", folderName);
                // TODO: mark the DB as invalid?
            }
            
            NSString *folderSelectSql = [NSString stringWithFormat:@"SELECT MESSAGE FROM FOLDER%@ ORDER BY UID DESC LIMIT %lu OFFSET %lu", folderId, count, offset];
            const char *folderSelectStmt = [folderSelectSql UTF8String];
            
            sqlite3_stmt *statement = NULL;
            const int sqlSelectPrepareResult = sqlite3_prepare_v2(database, folderSelectStmt, -1, &statement, NULL);

            NSMutableArray *messages = [NSMutableArray arrayWithCapacity:count];
            
            if(sqlSelectPrepareResult == SQLITE_OK) {
                while(sqlite3_step(statement) == SQLITE_ROW) {
                    int dataSize = sqlite3_column_bytes(statement, 0);
                    NSData *data = [NSData dataWithBytesNoCopy:(void *)sqlite3_column_blob(statement, 0) length:dataSize freeWhenDone:NO];
                    NSData *uncompressedData = [SMCompression gzipInflate:data];
                    
                    MCOIMAPMessage *message = [NSKeyedUnarchiver unarchiveObjectWithData:uncompressedData];
                    NSAssert(message != nil, @"could not decode IMAP message");
                    
                    [messages addObject:message];
                }
                // TODO: error handling
            }
            else {
                SM_LOG_ERROR(@"could not prepare select statement from folder %@ (id %@), error %d", folderName, folderId, sqlSelectPrepareResult);
                // TODO
            }
            
            const int sqlFinalizeResult = sqlite3_finalize(statement);
            SM_LOG_NOISE(@"finalize message count statement result %d", sqlFinalizeResult);
            
            [self closeDatabase:database];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                getMessagesBlock(messages);
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
                if(sqlite3_step(statement) == SQLITE_ROW) {
                    int dataSize = sqlite3_column_bytes(statement, 0);
                    NSData *data = [NSData dataWithBytesNoCopy:(void *)sqlite3_column_blob(statement, 0) length:dataSize freeWhenDone:NO];
                    NSData *uncompressedData = [SMCompression gzipInflate:data];

                    messageBody = uncompressedData;
                }
            }
            else {
                SM_LOG_ERROR(@"could not prepare load statement, error %d", sqlPrepareResult);
                // TODO
            }
            
            const int sqlFinalizeResult = sqlite3_finalize(statement);
            SM_LOG_NOISE(@"finalize message count statement result %d", sqlFinalizeResult);
            
            [self closeDatabase:database];
            
            MCOMessageParser *parser = [MCOMessageParser messageParserWithData:messageBody];
            NSArray *attachments = parser.attachments; // note that this is potentially long operation, so do it in the current thread

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
            NSNumber *folderId = [_folderIds objectForKey:folderName];
            if(folderId == nil) {
                SM_LOG_ERROR(@"No id for folder \"%@\" found in DB", folderName);
                // TODO: mark the DB as invalid?
            }
            
            NSString *folderInsertSql = [NSString stringWithFormat:@"INSERT INTO FOLDER%@ (\"UID\", \"MESSAGE\") VALUES (?, ?)", folderId];
            const char *folderInsertStmt = [folderInsertSql UTF8String];

            sqlite3_stmt *statement = NULL;
            const int sqlPrepareResult = sqlite3_prepare_v2(database, folderInsertStmt, -1, &statement, NULL);
            if(sqlPrepareResult != SQLITE_OK) {
                SM_LOG_ERROR(@"could not prepare load statement, error %d", sqlPrepareResult);
                // TODO
            }
            
            int bindResult;
            if((bindResult = sqlite3_bind_int(statement, 1, imapMessage.uid)) != SQLITE_OK) {
                SM_LOG_ERROR(@"message UID %u, could not bind argument 1 (UID), error %d", imapMessage.uid, bindResult);
                // TODO
            }
            
            NSData *encodedMessage = [self encodeImapMessage:imapMessage];
            
            if((bindResult = sqlite3_bind_blob(statement, 2, encodedMessage.bytes, (int)encodedMessage.length, SQLITE_STATIC)) != SQLITE_OK) {
                SM_LOG_ERROR(@"message UID %u, could not bind argument 2 (MESSAGE), error %d", imapMessage.uid, bindResult);
            }
            
            const int sqlResult = sqlite3_step(statement);
            if(sqlResult == SQLITE_DONE) {
                SM_LOG_DEBUG(@"Message with UID %u successfully inserted to folder \"%@\" (id %@)", imapMessage.uid, folderName, folderId);
            } else if(sqlResult == SQLITE_CONSTRAINT) {
                SM_LOG_ERROR(@"Message with UID %u already in folder \"%@\" (id %@)", imapMessage.uid, folderName, folderId);
            } else {
                SM_LOG_ERROR(@"Failed to insert message with UID %u in folder \"%@\" (id %@), error %d", imapMessage.uid, folderName, folderId, sqlResult);
            }
            
            const int sqlFinalizeResult = sqlite3_finalize(statement);
            SM_LOG_NOISE(@"finalize folders insert statement result %d", sqlFinalizeResult);
            
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
            NSNumber *folderId = [_folderIds objectForKey:folderName];
            if(folderId == nil) {
                SM_LOG_ERROR(@"No id for folder \"%@\" found in DB", folderName);
                // TODO: mark the DB as invalid?
            }

            NSString *updateSql = [NSString stringWithFormat:@"UPDATE FOLDER%@ SET MESSAGE = ? WHERE UID = %u", folderId, imapMessage.uid];
            const char *updateStmt = [updateSql UTF8String];
            
            sqlite3_stmt *statement = NULL;
            const int sqlPrepareResult = sqlite3_prepare_v2(database, updateStmt, -1, &statement, NULL);
            if(sqlPrepareResult != SQLITE_OK) {
                SM_LOG_ERROR(@"could not prepare update statement, error %d", sqlPrepareResult);
                // TODO
            }
            
            NSData *encodedMessage = [self encodeImapMessage:imapMessage];
            
            const int bindResult = sqlite3_bind_blob(statement, 1, encodedMessage.bytes, (int)encodedMessage.length, SQLITE_STATIC);
            if(bindResult != SQLITE_OK) {
                SM_LOG_ERROR(@"message UID %u, could not bind argument 1 (MESSAGE), error %d", imapMessage.uid, bindResult);
            }
            
            const int sqlResult = sqlite3_step(statement);
            if(sqlResult == SQLITE_DONE) {
                SM_LOG_DEBUG(@"Message with UID %u successfully udpated in folder \"%@\" (id %@)", imapMessage.uid, folderName, folderId);
            } else {
                SM_LOG_ERROR(@"Failed to upated message with UID %u in folder \"%@\" (id %@), error %d", imapMessage.uid, folderName, folderId, sqlResult);
            }
            
            const int sqlFinalizeResult = sqlite3_finalize(statement);
            SM_LOG_NOISE(@"finalize folders insert statement result %d", sqlFinalizeResult);
            
            [self closeDatabase:database];
        }
        
        OSAtomicAdd32(-1, &_serialQueueLength);
    });
}

- (void)removeMessageFromFolderTable:(sqlite3*)database uid:(uint32_t)uid folder:(NSString*)folderName {
    NSNumber *folderId = [_folderIds objectForKey:folderName];
    if(folderId == nil) {
        SM_LOG_ERROR(@"No id for folder \"%@\" found in DB", folderName);
        // TODO: mark the DB as invalid?
        return;
    }
    
    NSString *removeSql = [NSString stringWithFormat:@"DELETE FROM FOLDER%@ WHERE UID = \"%u\"", folderId, uid];
    const char *removeStmt = [removeSql UTF8String];
    
    sqlite3_stmt *statement = NULL;
    const int sqlPrepareResult = sqlite3_prepare_v2(database, removeStmt, -1, &statement, NULL);
    if(sqlPrepareResult != SQLITE_OK) {
        SM_LOG_ERROR(@"Could not prepare remove statement for message UID %u, folder %@ (%@), error %d", uid, folderName, folderId, sqlPrepareResult);
    }
    
    int sqlResult = sqlite3_step(statement);
    if(sqlResult == SQLITE_DONE) {
        SM_LOG_INFO(@"Message UID %u successfully removed from folder %@ (%@)", uid, folderName, folderId);
    } else {
        SM_LOG_INFO(@"Failed to remove message UID %u from folder %@ (%@)", uid, folderName, folderId);
    }
    
    const int sqlFinalizeResult = sqlite3_finalize(statement);
    SM_LOG_NOISE(@"finalize folders remove statement result %d", sqlFinalizeResult);
}

- (void)removeMessageBodyFromMessageBodiesTable:(sqlite3*)database folderName:(NSString*)folderName uid:(uint32_t)uid {
    NSNumber *folderId = [_folderIds objectForKey:folderName];
    if(folderId == nil) {
        SM_LOG_ERROR(@"No id for folder \"%@\" found in DB", folderName);
        // TODO: mark the DB as invalid?
    }
    
    NSString *removeSql = [NSString stringWithFormat:@"DELETE FROM MESSAGEBODIES%@ WHERE UID = \"%u\"", folderId, uid];
    const char *removeStmt = [removeSql UTF8String];
    
    sqlite3_stmt *statement = NULL;
    const int sqlPrepareResult = sqlite3_prepare_v2(database, removeStmt, -1, &statement, NULL);
    if(sqlPrepareResult != SQLITE_OK) {
        SM_LOG_ERROR(@"Could not prepare message body (UID %u) remove statement for folder '%@' (%@), error %d", uid, folderName, folderId, sqlPrepareResult);
    }
    
    int sqlResult = sqlite3_step(statement);
    if(sqlResult == SQLITE_DONE) {
        SM_LOG_INFO(@"Message body with UID %u successfully removed from message bodies table for folder '%@' (%@)", uid, folderName, folderId);
    } else {
        SM_LOG_ERROR(@"Failed to remove message body with UID %u for folder '%@' (%@), error %d", uid, folderName, folderId, sqlResult);
    }
    
    const int sqlFinalizeResult = sqlite3_finalize(statement);
    SM_LOG_NOISE(@"finalize folders remove statement result %d", sqlFinalizeResult);
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
            [self removeMessageFromFolderTable:database uid:uid folder:folderName];
            [self removeMessageBodyFromMessageBodiesTable:database folderName:folderName uid:uid];
            [self closeDatabase:database];
        }

        OSAtomicAdd32(-1, &_serialQueueLength);
    });
}

- (void)putMessageBodyToDB:(uint32_t)uid data:(NSData*)data folderName:(NSString*)folderName {
    NSNumber *folderId = [_folderIds objectForKey:folderName];
    if(folderId == nil) {
        SM_LOG_ERROR(@"No id for folder \"%@\" found in DB", folderName);
        // TODO
    }
    
    NSMutableSet *uidSet = [_messagesWithBodies objectForKey:folderId];
    if(uidSet == nil) {
        SM_LOG_WARNING(@"folder '%@' (%@) is unknown", folderName, folderId);
        // TODO
    }
    
    [uidSet addObject:[NSNumber numberWithUnsignedInt:uid]];

    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_DEBUG(@"serial queue length: %d", serialQueueLen);
    
    dispatch_async(_serialQueue, ^{
        sqlite3 *database = [self openDatabase];
        
        if(database != nil) {
            NSString *insertSql = [NSString stringWithFormat:@"INSERT INTO MESSAGEBODIES%@ (\"UID\", \"MESSAGEBODY\") VALUES (?, ?)", folderId];
            
            sqlite3_stmt *statement = NULL;
            const int sqlPrepareResult = sqlite3_prepare_v2(database, insertSql.UTF8String, -1, &statement, NULL);
            
            if(sqlPrepareResult != SQLITE_OK) {
                SM_LOG_ERROR(@"could not prepare load statement, error %d", sqlPrepareResult);
            }
            
            int bindResult;
            if((bindResult = sqlite3_bind_int(statement, 1, uid)) != SQLITE_OK) {
                SM_LOG_ERROR(@"message UID %u, could not bind argument 1 (UID), error %d", uid, bindResult);
            }
            
            NSData *compressedData = [SMCompression gzipDeflate:data];
            
            SM_LOG_DEBUG(@"message UID %u, data len %lu, compressed len %lu (%lu%% from original)", uid, data.length, compressedData.length, compressedData.length/(data.length/100));
            
            if((bindResult = sqlite3_bind_blob(statement, 2, compressedData.bytes, (int)compressedData.length, SQLITE_STATIC)) != SQLITE_OK) {
                SM_LOG_ERROR(@"message UID %u, could not bind argument 2 (MESSAGEBODY), error %d", uid, bindResult);
            }
            
            const int sqlInsertResult = sqlite3_step(statement);
            if(sqlInsertResult == SQLITE_DONE) {
                SM_LOG_DEBUG(@"Message with UID %u successfully inserted", uid);
            } else if(sqlInsertResult == SQLITE_CONSTRAINT) {
                // TODO: restore WARNING; don't rewrite messages on first launch
                SM_LOG_DEBUG(@"Message with UID %u already exists", uid);
            } else {
                SM_LOG_ERROR(@"Failed to insert message with UID %u, error %d", uid, sqlInsertResult);
            }
            
            const int sqlFinalizeResult = sqlite3_finalize(statement);
            SM_LOG_NOISE(@"finalize messages insert statement result %d", sqlFinalizeResult);
            
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
            // TODO: mark the DB as invalid?
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

- (void)putMessageThreadInDB:(SMMessageThreadDescriptor*)messageThread {
    const uint64_t messageThreadId = messageThread.threadId;
    
    if(messageThread.messagesCount <= 1) {
        SM_LOG_NOISE(@"message thread %llu is short and won't be saved in the database", messageThreadId);
        return;
    }
    
    NSData *serializedMessageThread = [self serializeMessageThread:messageThread];
    NSAssert(serializedMessageThread != nil, @"Could not serialize message thread (threadId %llu)", messageThreadId);
    
    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_DEBUG(@"serial queue length: %d", serialQueueLen);
    
    dispatch_async(_serialQueue, ^{
        sqlite3 *database = [self openDatabase];
        
        if(database != nil) {
            
            NSString *insertSql = @"INSERT INTO MESSAGETHREADS (\"THREADID\", \"UIDARRAY\") VALUES (?, ?)";
            
            sqlite3_stmt *statement = NULL;
            const int sqlPrepareResult = sqlite3_prepare_v2(database, insertSql.UTF8String, -1, &statement, NULL);
            
            if(sqlPrepareResult != SQLITE_OK) {
                SM_LOG_ERROR(@"could not prepare insert statement, error %d", sqlPrepareResult);
            }
            
            int bindResult;
            if((bindResult = sqlite3_bind_int64(statement, 1, messageThreadId)) != SQLITE_OK) {
                SM_LOG_ERROR(@"message thread %llu, could not bind argument 1 (THREADID), error %d", messageThreadId, bindResult);
            }
            
            if((bindResult = sqlite3_bind_blob(statement, 2, serializedMessageThread.bytes, (int)serializedMessageThread.length, SQLITE_STATIC)) != SQLITE_OK) {
                SM_LOG_ERROR(@"message thread %llu, could not bind argument 2 (UIDARRAY), error %d", messageThreadId, bindResult);
            }
            
            const int sqlInsertResult = sqlite3_step(statement);
            if(sqlInsertResult == SQLITE_DONE) {
                SM_LOG_DEBUG(@"message thread %llu successfully inserted", messageThreadId);
            } else if(sqlInsertResult == SQLITE_CONSTRAINT) {
                SM_LOG_ERROR(@"message thread %llu already exists in the database", messageThreadId);
            } else {
                SM_LOG_ERROR(@"failed to insert message thread %llu, error %d", messageThreadId, sqlInsertResult);
            }
            
            const int sqlFinalizeResult = sqlite3_finalize(statement);
            SM_LOG_NOISE(@"finalize messages insert statement result %d", sqlFinalizeResult);
            
            [self closeDatabase:database];
        }
        
        OSAtomicAdd32(-1, &_serialQueueLength);
    });
}

- (void)updateMessageThreadInDB:(SMMessageThreadDescriptor*)messageThread {
    const uint64_t messageThreadId = messageThread.threadId;
    
    if(messageThread.messagesCount <= 1) {
        [self removeMessageThreadFromDB:messageThreadId];
        return;
    }
    
    NSData *serializedMessageThread = [self serializeMessageThread:messageThread];
    NSAssert(serializedMessageThread != nil, @"Could not serialize message thread (threadId %llu)", messageThreadId);
    
    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_DEBUG(@"serial queue length: %d", serialQueueLen);
    
    dispatch_async(_serialQueue, ^{
        sqlite3 *database = [self openDatabase];
        
        if(database != nil) {
            //
            // Step 1: check if this message thread already exists in the DB.
            //
            NSString *selectSql = [NSString stringWithFormat:@"SELECT UIDARRAY FROM MESSAGETHREADS WHERE THREADID = %llu", messageThreadId];
            
            sqlite3_stmt *selectStatement = NULL;
            const int sqlSelectPrepareResult = sqlite3_prepare_v2(database, selectSql.UTF8String, -1, &selectStatement, NULL);
            
            if(sqlSelectPrepareResult != SQLITE_OK) {
                SM_LOG_ERROR(@"could not prepare select statement, error %d", sqlSelectPrepareResult);
                // TODO
            }
            
            const int sqlSelectStepResult = sqlite3_step(selectStatement);
            
            if(sqlSelectStepResult == SQLITE_ROW) {
                //
                // Step 2a: As there's already some data, just update it.
                //
                NSString *updateSql = [NSString stringWithFormat:@"UPDATE MESSAGETHREADS SET UIDARRAY = ? WHERE THREADID = %llu", messageThreadId];
                
                sqlite3_stmt *statement = NULL;
                const int sqlPrepareResult = sqlite3_prepare_v2(database, updateSql.UTF8String, -1, &statement, NULL);
                
                if(sqlPrepareResult != SQLITE_OK) {
                    SM_LOG_ERROR(@"could not prepare update statement, error %d", sqlPrepareResult);
                }
                
                int bindResult = sqlite3_bind_blob(statement, 1, serializedMessageThread.bytes, (int)serializedMessageThread.length, SQLITE_STATIC);
                if(bindResult != SQLITE_OK) {
                    SM_LOG_ERROR(@"message thread %llu, could not bind argument 1 (UIDARRAY), error %d", messageThreadId, bindResult);
                }
                
                const int sqlUpdateResult = sqlite3_step(statement);
                if(sqlUpdateResult == SQLITE_DONE) {
                    SM_LOG_DEBUG(@"message thread %llu successfully updated", messageThreadId);
                } else {
                    SM_LOG_ERROR(@"failed to update message thread %llu, error %d", messageThreadId, sqlUpdateResult);
                }
                
                const int sqlFinalizeResult = sqlite3_finalize(statement);
                SM_LOG_NOISE(@"finalize messages update statement result %d", sqlFinalizeResult);
            }
            else if(sqlSelectStepResult == SQLITE_DONE) {
                //
                // Step 2b: Existing message thread not found, insert the new data.
                //
                NSString *insertSql = @"INSERT INTO MESSAGETHREADS (\"THREADID\", \"UIDARRAY\") VALUES (?, ?)";
                
                sqlite3_stmt *statement = NULL;
                const int sqlPrepareResult = sqlite3_prepare_v2(database, insertSql.UTF8String, -1, &statement, NULL);
                
                if(sqlPrepareResult != SQLITE_OK) {
                    SM_LOG_ERROR(@"could not prepare insert statement, error %d", sqlPrepareResult);
                }
                
                int bindResult;
                if((bindResult = sqlite3_bind_int64(statement, 1, messageThreadId)) != SQLITE_OK) {
                    SM_LOG_ERROR(@"message thread %llu, could not bind argument 1 (THREADID), error %d", messageThreadId, bindResult);
                }
                
                if((bindResult = sqlite3_bind_blob(statement, 2, serializedMessageThread.bytes, (int)serializedMessageThread.length, SQLITE_STATIC)) != SQLITE_OK) {
                    SM_LOG_ERROR(@"message thread %llu, could not bind argument 2 (UIDARRAY), error %d", messageThreadId, bindResult);
                }
                
                const int sqlInsertResult = sqlite3_step(statement);
                if(sqlInsertResult == SQLITE_DONE) {
                    SM_LOG_DEBUG(@"message thread %llu successfully inserted", messageThreadId);
                } else if(sqlInsertResult == SQLITE_CONSTRAINT) {
                    SM_LOG_ERROR(@"message thread %llu already exists in the database", messageThreadId);
                } else {
                    SM_LOG_ERROR(@"failed to insert message thread %llu, error %d", messageThreadId, sqlInsertResult);
                }
                
                const int sqlFinalizeResult = sqlite3_finalize(statement);
                SM_LOG_NOISE(@"finalize messages insert statement result %d", sqlFinalizeResult);
            }
            else {
                SM_LOG_ERROR(@"failed select message thread %llu, error %d", messageThreadId, sqlSelectStepResult);
            }

            const int sqlFinalizeResult = sqlite3_finalize(selectStatement);
            SM_LOG_NOISE(@"finalize messages select statement result %d", sqlFinalizeResult);

            [self closeDatabase:database];
        }
        
        OSAtomicAdd32(-1, &_serialQueueLength);
    });
}

- (void)removeMessageThreadFromDB:(uint64_t)messageThreadId {
    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_DEBUG(@"serial queue length: %d", serialQueueLen);
    
    dispatch_async(_serialQueue, ^{
        sqlite3 *database = [self openDatabase];
        
        if(database != nil) {
            NSString *insertSql = [NSString stringWithFormat:@"DELETE FROM MESSAGETHREADS WHERE THREADID = %llu", messageThreadId];
            
            sqlite3_stmt *statement = NULL;
            const int sqlPrepareResult = sqlite3_prepare_v2(database, insertSql.UTF8String, -1, &statement, NULL);
            
            if(sqlPrepareResult != SQLITE_OK) {
                SM_LOG_ERROR(@"could not prepare remove statement, error %d", sqlPrepareResult);
            }
            
            const int sqlRemoveResult = sqlite3_step(statement);
            if(sqlRemoveResult == SQLITE_DONE) {
                SM_LOG_INFO(@"message thread %llu successfully removed", messageThreadId);
            } else {
                SM_LOG_ERROR(@"failed to remove message thread %llu, error %d", messageThreadId, sqlRemoveResult);
            }
            
            const int sqlFinalizeResult = sqlite3_finalize(statement);
            SM_LOG_NOISE(@"finalize messages insert statement result %d", sqlFinalizeResult);
            
            [self closeDatabase:database];
        }
        
        OSAtomicAdd32(-1, &_serialQueueLength);
    });
}

- (void)loadMessageThreadFromDB:(uint64_t)messageThreadId block:(void (^)(SMMessageThreadDescriptor*))getMessageThreadBlock {
    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_DEBUG(@"serial queue length: %d", serialQueueLen);
    
    dispatch_async(_serialQueue, ^{
        sqlite3 *database = [self openDatabase];
        
        if(database != nil) {
            NSString *insertSql = [NSString stringWithFormat:@"SELECT UIDARRAY FROM MESSAGETHREADS WHERE THREADID = %llu", messageThreadId];
            
            sqlite3_stmt *statement = NULL;
            const int sqlPrepareResult = sqlite3_prepare_v2(database, insertSql.UTF8String, -1, &statement, NULL);
            
            if(sqlPrepareResult != SQLITE_OK) {
                SM_LOG_ERROR(@"could not prepare remove statement, error %d", sqlPrepareResult);
            }
            
            SMMessageThreadDescriptor *messageThreadDesc = nil;
            
            const int sqlLoadResult = sqlite3_step(statement);
            if(sqlLoadResult == SQLITE_ROW) {
                int dataSize = sqlite3_column_bytes(statement, 0);
                NSData *data = [NSData dataWithBytesNoCopy:(void *)sqlite3_column_blob(statement, 0) length:dataSize freeWhenDone:NO];

                messageThreadDesc = [self deserializeMessageThread:messageThreadId data:data];
                NSAssert(messageThreadDesc != nil, @"could not deserialize message thread %llu", messageThreadId);

                SM_LOG_INFO(@"message thread %llu loaded, messages count %lu", messageThreadId, messageThreadDesc.messagesCount);
            }
            else if(sqlLoadResult == SQLITE_DONE) {
                SM_LOG_DEBUG(@"message thread %llu not found in the database", messageThreadId);
            }
            else {
                SM_LOG_ERROR(@"failed to load message thread %llu, error %d", messageThreadId, sqlLoadResult);
            }
            
            const int sqlFinalizeResult = sqlite3_finalize(statement);
            SM_LOG_NOISE(@"finalize messages insert statement result %d", sqlFinalizeResult);
            
            [self closeDatabase:database];

            dispatch_async(dispatch_get_main_queue(), ^{
                getMessageThreadBlock(messageThreadDesc);
            });
        }
        
        OSAtomicAdd32(-1, &_serialQueueLength);
    });
}

@end
