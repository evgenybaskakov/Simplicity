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
    [self openDatabase];

    {
        char *errMsg = NULL;
        const char *createStmt = "CREATE TABLE IF NOT EXISTS FOLDERS (ID INTEGER PRIMARY KEY AUTOINCREMENT, NAME TEXT UNIQUE, DELIMITER INTEGER, FLAGS INTEGER)";
        
        const int sqlResult = sqlite3_exec(_database, createStmt, NULL, NULL, &errMsg);
        if(sqlResult != SQLITE_OK) {
            SM_LOG_ERROR(@"Failed to create table FOLDERS: %s, error %d", errMsg, sqlResult);
            // TODO: mark the DB as invalid?
        }
    }

    {
        char *errMsg = NULL;
        const char *createStmt = "CREATE TABLE IF NOT EXISTS MESSAGES (UID INTEGER PRIMARY KEY, MESSAGE BLOB)";
        
        const int sqlResult = sqlite3_exec(_database, createStmt, NULL, NULL, &errMsg);
        if(sqlResult != SQLITE_OK) {
            SM_LOG_ERROR(@"Failed to create table MESSAGES: %s, error %d", errMsg, sqlResult);
            // TODO: mark the DB as invalid?
        }
    }
    
    [self closeDatabase];
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
    
    NSDictionary *results = [[NSMutableDictionary alloc] init];
    
    [results setValue:arrColumnNames forKey:@"Columns"];
    [results setValue:arrRows forKey:@"Rows"];
    
    return results;
}

- (void)addDBFolder:(NSString*)folderName delimiter:(char)delimiter flags:(MCOIMAPFolderFlag)flags {
    dispatch_async(_serialQueue, ^{
        if([self openDatabase]) {
            NSString *insertSql = [NSString stringWithFormat: @"INSERT INTO FOLDERS (NAME, DELIMITER, FLAGS) VALUES (\"%@\", %ld, %ld)", folderName, (NSInteger)delimiter, (NSInteger)flags];
            const char *insertStmt = [insertSql UTF8String];
            
            sqlite3_stmt *statement = NULL;
            const int sqlPrepareResult = sqlite3_prepare_v2(_database, insertStmt, -1, &statement, NULL);
            if(sqlPrepareResult != SQLITE_OK) {
                SM_LOG_ERROR(@"could not prepare folders insert statement, error %d", sqlPrepareResult);
            }
            
            const int sqlResult = sqlite3_step(statement);
            if(sqlResult == SQLITE_DONE) {
                SM_LOG_INFO(@"Folder %@ successfully inserted", folderName);
            } else if(sqlResult == SQLITE_CONSTRAINT) {
                SM_LOG_DEBUG(@"Folder %@ already exists", folderName);
            } else {
                SM_LOG_ERROR(@"Failed to insert folder %@, error %d", folderName, sqlResult);
            }
            
            const int sqlFinalizeResult = sqlite3_finalize(statement);
            SM_LOG_NOISE(@"finalize folders insert statement result %d", sqlFinalizeResult);
            
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

- (NSArray*)getMessageHeadersFromDBFolder:(NSString*)nameName {
    NSAssert(nil, @"TODO");
    return nil;
}

- (NSArray*)getMessageBodyForUIDFromDB:(uint32_t*)uid {
    NSAssert(nil, @"TODO");
    return nil;
}

- (void)putMessageToDBFolder:(MCOIMAPMessage*)imapMessage folder:(NSString*)nameName {
    dispatch_async(_serialQueue, ^{
        if([self openDatabase]) {
            NSData *encodedMessage = [NSKeyedArchiver archivedDataWithRootObject:imapMessage];
            NSAssert(encodedMessage != nil, @"could not encode IMAP message");

            const char *insertStmt = "INSERT INTO MESSAGES (\"UID\", \"MESSAGE\") VALUES (?, ?)";
            
            sqlite3_stmt *statement = NULL;
            const int sqlPrepareResult = sqlite3_prepare_v2(_database, insertStmt, -1, &statement, NULL);
            
            if(sqlPrepareResult == SQLITE_OK) {
                int bindResult;
                if((bindResult = sqlite3_bind_int(statement, 1, imapMessage.uid)) != SQLITE_OK) {
                    SM_LOG_ERROR(@"message UID %u, could not bind argument 1", imapMessage.uid);
                }
                if((bindResult = sqlite3_bind_blob(statement, 2, [encodedMessage bytes], (int)[encodedMessage length], SQLITE_STATIC)) != SQLITE_OK) {
                    SM_LOG_ERROR(@"message UID %u, could not bind argument 2", imapMessage.uid);
                }
            }
            
            const int sqlInsertResult = sqlite3_step(statement);
            if(sqlInsertResult == SQLITE_DONE) {
                SM_LOG_INFO(@"Message with UID %u successfully inserted", imapMessage.uid);
            } else if(sqlInsertResult == SQLITE_CONSTRAINT) {
                SM_LOG_WARNING(@"Message with UID %u already exists", imapMessage.uid);
            } else {
                SM_LOG_ERROR(@"Failed to insert message with UID %u, error %d", imapMessage.uid, sqlInsertResult);
            }
            
            const int sqlFinalizeResult = sqlite3_finalize(statement);
            SM_LOG_NOISE(@"finalize messages insert statement result %d", sqlFinalizeResult);
            
            [self closeDatabase];
        }
    });
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
