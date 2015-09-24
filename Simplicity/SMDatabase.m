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
#import "SMMailboxController.h"
#import "SMDatabase.h"

@implementation SMDatabase {
    NSString *_dbFilePath;
    sqlite3 *_database;
    dispatch_queue_t _serialQueue;
    NSMutableDictionary *_folderIds;
}

- (id)initWithFilePath:(NSString*)dbFilePath {
    self = [self init];

    if(self) {
        _serialQueue = dispatch_queue_create("com.simplicity.Simplicity.serialDatabaseQueue", DISPATCH_QUEUE_SERIAL);
        _dbFilePath = dbFilePath;
        
        [self initDatabase];
    }
    
    return self;
}

- (BOOL)openDatabase {
    NSAssert(_database == nil, @"datase already open");

    const int openDatabaseResult = sqlite3_open([_dbFilePath UTF8String], &_database);
    if(openDatabaseResult == SQLITE_OK) {
        SM_LOG_DEBUG(@"Database %@ open successfully", _dbFilePath);
        return TRUE;
    }
    else {
        SM_LOG_FATAL(@"Database %@ cannot be open", _dbFilePath);
        return FALSE;
    }
}

- (void)closeDatabase {
    const int sqlCloseResult = sqlite3_close(_database);
    
    if(sqlCloseResult != SQLITE_OK) {
        SM_LOG_ERROR(@"could not close database, error %d", sqlCloseResult);
    }
    
    _database = NULL;
}

- (void)initDatabase {
    if([self openDatabase]) {
        [self createFoldersTable];
        [self createMessagesTable];
        [self loadFolderIds];
        [self closeDatabase];
    }
}

- (void)createFoldersTable {
    char *errMsg = NULL;
    const char *createStmt = "CREATE TABLE IF NOT EXISTS FOLDERS (ID INTEGER PRIMARY KEY AUTOINCREMENT, NAME TEXT UNIQUE, DELIMITER INTEGER, FLAGS INTEGER)";
    
    const int sqlResult = sqlite3_exec(_database, createStmt, NULL, NULL, &errMsg);
    if(sqlResult != SQLITE_OK) {
        SM_LOG_ERROR(@"Failed to create table FOLDERS: %s, error %d", errMsg, sqlResult);
        // TODO: mark the DB as invalid?
    }
}

- (void)createFolderMessagesTable:(NSString*)folderName {
    NSNumber *folderId = [_folderIds objectForKey:folderName];
    if(folderId == nil) {
        SM_LOG_ERROR(@"No id for folder \"%@\" found in DB", folderName);
        // TODO: mark the DB as invalid?
    }
    
    NSString *createSql = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS FOLDER%@ (UID INTEGER PRIMARY KEY UNIQUE)", folderId];
    const char *createStmt = [createSql UTF8String];
    
    char *errMsg = NULL;
    const int sqlResult = sqlite3_exec(_database, createStmt, NULL, NULL, &errMsg);
    if(sqlResult != SQLITE_OK) {
        SM_LOG_ERROR(@"Failed to create table for folder \"%@\" (id %@): %s, error %d", folderName, folderId, errMsg, sqlResult);
        // TODO: mark the DB as invalid?
    }
}

- (void)createMessagesTable {
    char *errMsg = NULL;
    const char *createStmt = "CREATE TABLE IF NOT EXISTS MESSAGES (UID INTEGER PRIMARY KEY UNIQUE, REFCOUNT INTEGER, MESSAGE BLOB)";
    
    const int sqlResult = sqlite3_exec(_database, createStmt, NULL, NULL, &errMsg);
    if(sqlResult != SQLITE_OK) {
        SM_LOG_ERROR(@"Failed to create table MESSAGES: %s, error %d", errMsg, sqlResult);
        // TODO: mark the DB as invalid?
    }
}

- (NSDictionary*)loadDataFromDB:(const char *)sqlQuery {
    NSAssert(_database != nil, @"no database open");
    
    sqlite3_stmt *statement = NULL;
    const int sqlPrepareResult = sqlite3_prepare_v2(_database, sqlQuery, -1, &statement, NULL);
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

- (void)loadFolderIds {
    _folderIds = [[NSMutableDictionary alloc] init];

    const char *sqlQuery = "SELECT * FROM FOLDERS";
    NSDictionary *foldersTable = [self loadDataFromDB:sqlQuery];
    NSArray *columns = [foldersTable objectForKey:@"Columns"];
    NSArray *rows = [foldersTable objectForKey:@"Rows"];
    
    const NSInteger idColumn = [columns indexOfObject:@"ID"];
    const NSInteger nameColumn = [columns indexOfObject:@"NAME"];
    
    if(idColumn != NSNotFound && nameColumn != NSNotFound) {
        for(NSUInteger i = 0; i < rows.count; i++) {
            NSArray *row = rows[i];
            NSString *idStr = row[idColumn];
            NSString *nameStr = row[nameColumn];
            NSUInteger folderId = [idStr integerValue];

            [_folderIds setObject:[NSNumber numberWithUnsignedInteger:folderId] forKey:nameStr];
            
            SM_LOG_DEBUG(@"Folder \"%@\" id %lu", nameStr, folderId);
        }
    }
}

- (void)loadFolderId:(NSString*)folderName {
    NSString *selectSql = [NSString stringWithFormat: @"SELECT ID FROM FOLDERS WHERE NAME = \"%@\"", folderName];
    const char *sqlQuery = [selectSql UTF8String];
    NSDictionary *foldersTable = [self loadDataFromDB:sqlQuery];
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
        NSUInteger folderId = [idStr integerValue];
        
        [_folderIds setObject:[NSNumber numberWithUnsignedInteger:folderId] forKey:folderName];
        
        SM_LOG_DEBUG(@"Folder \"%@\" id %lu", folderName, folderId);
    }
}

- (void)addDBFolder:(NSString*)folderName delimiter:(char)delimiter flags:(MCOIMAPFolderFlag)flags {
    dispatch_async(_serialQueue, ^{
        if([self openDatabase]) {
            //
            // Step 1: Add the folder into the DB.
            //
            NSString *insertSql = [NSString stringWithFormat: @"INSERT INTO FOLDERS (NAME, DELIMITER, FLAGS) VALUES (\"%@\", %ld, %ld)", folderName, (NSInteger)delimiter, (NSInteger)flags];
            const char *insertStmt = [insertSql UTF8String];
            
            sqlite3_stmt *statement = NULL;
            const int sqlPrepareResult = sqlite3_prepare_v2(_database, insertStmt, -1, &statement, NULL);
            if(sqlPrepareResult != SQLITE_OK) {
                SM_LOG_ERROR(@"could not prepare folders insert statement, error %d", sqlPrepareResult);
            }
            
            BOOL newFolderAdded = NO;
            
            const int sqlResult = sqlite3_step(statement);
            if(sqlResult == SQLITE_DONE) {
                SM_LOG_DEBUG(@"Folder %@ successfully inserted", folderName);

                newFolderAdded = YES;
            } else if(sqlResult == SQLITE_CONSTRAINT) {
                SM_LOG_DEBUG(@"Folder %@ already exists", folderName);
            } else {
                SM_LOG_ERROR(@"Failed to insert folder %@, error %d", folderName, sqlResult);
            }
            
            const int sqlFinalizeResult = sqlite3_finalize(statement);
            SM_LOG_NOISE(@"finalize folders insert statement result %d", sqlFinalizeResult);

            if(newFolderAdded) {
                //
                // Step 2: For new folders, find out what's the ID of the newly added folder.
                //
                [self loadFolderId:folderName];
                
                //
                // Step 3: Create a unique folder table containing message UIDs.
                //
                [self createFolderMessagesTable:folderName];
            }
            
            [self closeDatabase];
        }
    });
}

- (void)renameDBFolder:(NSString*)folderName newName:(NSString*)newName {
    NSAssert(nil, @"TODO");
}

- (void)deleteDBFolder:(NSString*)folderName {
    dispatch_async(_serialQueue, ^{
        if([self openDatabase]) {
            NSString *deleteSql = [NSString stringWithFormat: @"DELETE FROM FOLDERS WHERE NAME = \"%@\"", folderName];
            const char *deleteStmt = [deleteSql UTF8String];

            sqlite3_stmt *statement = NULL;
            const int sqlPrepareResult = sqlite3_prepare_v2(_database, deleteStmt, -1, &statement, NULL);
            if(sqlPrepareResult != SQLITE_OK) {
                SM_LOG_ERROR(@"could not prepare folders delete statement, error %d", sqlPrepareResult);
            }
            
            int sqlResult = sqlite3_step(statement);
            if(sqlResult == SQLITE_DONE) {
                SM_LOG_INFO(@"Folder %@ successfully deleted", folderName);
            } else {
                SM_LOG_ERROR(@"Failed to delete folder %@, error %d", folderName, sqlResult);
            }
            
            const int sqlFinalizeResult = sqlite3_finalize(statement);
            SM_LOG_NOISE(@"finalize folders delete statement result %d", sqlFinalizeResult);
         
            [self closeDatabase];
        }
    });
}

- (void)loadDBFolders {
    dispatch_async(_serialQueue, ^{
        if([self openDatabase]) {
            NSMutableArray *folders = nil;
            
            const char *sqlQuery = "SELECT * FROM FOLDERS";
            NSDictionary *foldersTable = [self loadDataFromDB:sqlQuery];
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

            [self closeDatabase];

            dispatch_async(dispatch_get_main_queue(), ^{
                SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
                SMMailboxController *mailboxController = [[appDelegate model] mailboxController];
                
                [mailboxController loadExistingFolders:folders];
            });
        }
    });
}

- (NSArray*)getMessageHeadersFromDBFolder:(NSString*)folderName {
    NSAssert(nil, @"TODO");
    return nil;
}

- (NSArray*)getMessageBodyForUIDFromDB:(uint32_t*)uid {
    NSAssert(nil, @"TODO");
    return nil;
}

- (void)putMessageToDBFolder:(MCOIMAPMessage*)imapMessage folder:(NSString*)folderName {
    dispatch_async(_serialQueue, ^{
        if([self openDatabase]) {
            //
            // Step 1: Add the message UID to the given folder table.
            //
            NSNumber *folderId = [_folderIds objectForKey:folderName];
            if(folderId == nil) {
                SM_LOG_ERROR(@"No id for folder \"%@\" found in DB", folderName);
                // TODO: mark the DB as invalid?
            }
            
            NSString *folderInsertSql = [NSString stringWithFormat:@"INSERT INTO FOLDER%@ (\"UID\") VALUES (?)", folderId];
            const char *folderInsertStmt = [folderInsertSql UTF8String];

            sqlite3_stmt *statement = NULL;
            const int sqlPrepareResult = sqlite3_prepare_v2(_database, folderInsertStmt, -1, &statement, NULL);
            if(sqlPrepareResult != SQLITE_OK) {
                SM_LOG_ERROR(@"could not prepare load statement, error %d", sqlPrepareResult);
            }
            
            int bindResult;
            if((bindResult = sqlite3_bind_int(statement, 1, imapMessage.uid)) != SQLITE_OK) {
                SM_LOG_ERROR(@"message UID %u, could not bind argument 1 (UID), error %d", imapMessage.uid, bindResult);
            }
            
            BOOL messageUidInserted = NO;
            
            const int sqlResult = sqlite3_step(statement);
            if(sqlResult == SQLITE_DONE) {
                SM_LOG_DEBUG(@"Message UID %u successfully inserted to folder \"%@\" (id %@)", imapMessage.uid, folderName, folderId);
                
                messageUidInserted = YES;
            } else if(sqlResult == SQLITE_CONSTRAINT) {
                SM_LOG_DEBUG(@"Message UID %u already in folder \"%@\" (id %@)", imapMessage.uid, folderName, folderId);
            } else {
                SM_LOG_ERROR(@"Failed to insert message UID %u in folder \"%@\" (id %@), error %d", imapMessage.uid, folderName, folderId, sqlResult);
            }
            
            const int sqlFinalizeResult = sqlite3_finalize(statement);
            SM_LOG_NOISE(@"finalize folders insert statement result %d", sqlFinalizeResult);
            
            if(messageUidInserted) {
                //
                // Step 2: If the message UID has been inserted, add its body to the DB as well unless it is there yet.
                //
                NSData *encodedMessage = [NSKeyedArchiver archivedDataWithRootObject:imapMessage];
                NSAssert(encodedMessage != nil, @"could not encode IMAP message");

                const char *insertStmt = "INSERT INTO MESSAGES (\"UID\", \"REFCOUNT\", \"MESSAGE\") VALUES (?, ?, ?)";
                const int refCount = 1;
                
                sqlite3_stmt *statement = NULL;
                const int sqlPrepareResult = sqlite3_prepare_v2(_database, insertStmt, -1, &statement, NULL);
                
                if(sqlPrepareResult != SQLITE_OK) {
                    SM_LOG_ERROR(@"could not prepare load statement, error %d", sqlPrepareResult);
                }

                int bindResult;
                if((bindResult = sqlite3_bind_int(statement, 1, imapMessage.uid)) != SQLITE_OK) {
                    SM_LOG_ERROR(@"message UID %u, could not bind argument 1 (UID), error %d", imapMessage.uid, bindResult);
                }
                if((bindResult = sqlite3_bind_int(statement, 2, refCount)) != SQLITE_OK) {
                    SM_LOG_ERROR(@"message UID %u, could not bind argument 2 (REFCOUNT), error %d", imapMessage.uid, bindResult);
                }
                if((bindResult = sqlite3_bind_blob(statement, 3, [encodedMessage bytes], (int)[encodedMessage length], SQLITE_STATIC)) != SQLITE_OK) {
                    SM_LOG_ERROR(@"message UID %u, could not bind argument 3 (MESSAGE), error %d", imapMessage.uid, bindResult);
                }
                
                BOOL messageInserted = NO;
                
                const int sqlInsertResult = sqlite3_step(statement);
                if(sqlInsertResult == SQLITE_DONE) {
                    SM_LOG_DEBUG(@"Message with UID %u successfully inserted", imapMessage.uid);
                    
                    messageInserted = YES;
                } else if(sqlInsertResult == SQLITE_CONSTRAINT) {
                    // TODO: restore WARNING; don't rewrite messages on first launch
                    SM_LOG_DEBUG(@"Message with UID %u already exists", imapMessage.uid);
                } else {
                    SM_LOG_ERROR(@"Failed to insert message with UID %u, error %d", imapMessage.uid, sqlInsertResult);
                }
                
                const int sqlFinalizeResult = sqlite3_finalize(statement);
                SM_LOG_NOISE(@"finalize messages insert statement result %d", sqlFinalizeResult);
                
                if(!messageInserted) {
                    //
                    // Step 3: If the message has not been inserted, suppose it is already in the DB, so just increase the refcount.
                    //
                    
                    // TODO
                }
            }
            
            [self closeDatabase];
        }
    });
}

- (void)removeMessageFromDBFolder:(MCOIMAPMessage*)imapMessage folder:(NSString*)folderName {
}

- (void)updateMessageInDBFolder:(MCOIMAPMessage*)imapMessage folder:(NSString*)folderName {
    SM_LOG_DEBUG(@"TODO");
}

- (void)deleteMessageFromDB:(MCOIMAPMessage*)imapMessage {
    NSAssert(nil, @"TODO");
}

- (void)updateMessageFlagsInDB:(MCOIMAPMessage*)imapMessage {
    NSAssert(nil, @"TODO");
}

- (void)updateMessageLabelsInDB:(MCOIMAPMessage*)imapMessage {
    NSAssert(nil, @"TODO");
}


@end
