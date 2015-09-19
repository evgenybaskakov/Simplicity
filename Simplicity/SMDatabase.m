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
}

- (id)initWithFilePath:(NSString*)dbFilePath {
    self = [self init];

    if(self) {
        BOOL openDatabaseResult = sqlite3_open([dbFilePath UTF8String], &_database);
        if(openDatabaseResult == SQLITE_OK) {
            SM_LOG_INFO(@"Database %@ open successfully", dbFilePath);
            
            
            sqlite3_stmt *compiledStatement;
        
//            // Load all data from database to memory.
//            BOOL prepareStatementResult = sqlite3_prepare_v2(sqlite3Database, query, -1, &compiledStatement, NULL);
//            if(prepareStatementResult == SQLITE_OK) {
//            }
        }
        else {
            SM_LOG_INFO(@"Database %@ not found", dbFilePath);
        }

        _dbFilePath = dbFilePath;
    }
    
    return self;
}

- (void)addDBFolder:(SMFolder*)folder {
    NSAssert(nil, @"TODO");
}

- (void)renameDBFolder:(SMFolder*)folder newName:(NSString*)newName {
    NSAssert(nil, @"TODO");
}

- (void)deleteDBFolder:(SMFolder*)folder {
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
