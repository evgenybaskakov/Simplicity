//
//  SMDatabase.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/14/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <sqlite3.h>

#import "SMLog.h"
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
    }
    
    return self;
}

- (BOOL)openDatabase {
    NSAssert(_database == nil, @"datase already open");

    BOOL openDatabaseResult = sqlite3_open([_dbFilePath UTF8String], &_database);
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
    sqlite3_close(_database);
    _database = NULL;
}

// TODO: Check for vanished folders

- (void)addDBFolder:(NSString*)folderName {
    dispatch_async(_serialQueue, ^{
        if([self openDatabase]) {
            char *errMsg = NULL;
            const char *createStmt = "CREATE TABLE IF NOT EXISTS FOLDERS (ID INTEGER PRIMARY KEY AUTOINCREMENT, NAME TEXT UNIQUE)";
            
            int sqlResult = sqlite3_exec(_database, createStmt, NULL, NULL, &errMsg);
            if(sqlResult != SQLITE_OK) {
                SM_LOG_ERROR(@"Failed to create table: %s, error %d", errMsg, sqlResult);
            }
            
            NSString *insertSql = [NSString stringWithFormat: @"INSERT INTO FOLDERS (name) VALUES (\"%@\")", folderName];
            const char *insertStmt = [insertSql UTF8String];
            
            sqlite3_stmt *statement = NULL;
            sqlite3_prepare_v2(_database, insertStmt, -1, &statement, NULL);
            
            sqlResult = sqlite3_step(statement);
            if(sqlResult == SQLITE_DONE) {
                SM_LOG_DEBUG(@"Folder %@ successfully insered", folderName);
            } else if(sqlResult == SQLITE_CONSTRAINT) {
                SM_LOG_DEBUG(@"Folder %@ already exists", folderName);
            } else {
                SM_LOG_ERROR(@"Failed to insert folder %@, error %d", folderName, sqlResult);
            }
            
            sqlite3_finalize(statement);
            
            [self closeDatabase];
        }
    });
}

- (void)renameDBFolder:(NSString*)folderName newName:(NSString*)newName {
    NSAssert(nil, @"TODO");
}

- (void)deleteDBFolder:(NSString*)folderName {
    NSAssert(nil, @"TODO");
}

- (NSArray*)getDBFolders {
    NSAssert(nil, @"TODO");
    return nil;
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
    NSAssert(nil, @"TODO");
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
