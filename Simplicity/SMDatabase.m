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

- (NSDictionary*)loadDataFromDB:(const char *)sqlQuery {
    NSAssert(_database != nil, @"no database open");
    
    sqlite3_stmt *statement = NULL;
    sqlite3_prepare_v2(_database, sqlQuery, -1, &statement, NULL);
    
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

- (void)loadDBFolders {
    dispatch_async(_serialQueue, ^{
        if([self openDatabase]) {
            const char *sqlQuery = "SELECT * FROM FOLDERS";
            NSDictionary *foldersTable = [self loadDataFromDB:sqlQuery];
            NSArray *columns = [foldersTable objectForKey:@"Columns"];
            NSArray *rows = [foldersTable objectForKey:@"Rows"];
            
            const NSUInteger nameColumn = [columns indexOfObject:@"NAME"];
            if(nameColumn == NSNotFound) {
                SM_LOG_ERROR(@"database corrupted: folder name column not found");
                
                // TODO: trigger database drop
                rows = [NSArray array];
            }
            
            SM_LOG_WARNING(@"TODO: folder flags and delimiters not stored in DB");
            
            NSMutableArray *folders = [NSMutableArray arrayWithCapacity:rows.count];
            for(NSUInteger i = 0; i < rows.count; i++) {
                NSArray *row = rows[i];
                NSString *name = row[nameColumn];
                char delimiter = '/'; // TODO!
                MCOIMAPFolderFlag flags = 0; // TODO!
                
                folders[i] = [[SMFolderDesc alloc] initWithFolderName:name delimiter:delimiter flags:flags];
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
