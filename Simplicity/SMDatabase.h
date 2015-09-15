//
//  SMDatabase.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/14/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MCOIMAPMessage;
@class SMFolder;

@interface SMDatabase : NSObject

- (id)init:(NSString*)dbFilePath;
- (void)addDBFolder:(SMFolder*)folder;
- (void)renameDBFolder:(SMFolder*)folder newName:(NSString*)newName;
- (void)deleteDBFolder:(SMFolder*)folder;
- (NSArray*)getDBFolders;
- (NSArray*)getMessageHeadersFromDBFolder:(NSString*)nameName;
- (NSArray*)getMessageBodyForUIDFromDB:(uint32_t*)uid;
- (void)putMessageToDBFolder:(MCOIMAPMessage*)imapMessage folder:(NSString*)nameName;
- (void)deleteMessageFromDB:(MCOIMAPMessage*)imapMessage;
- (void)updateMessageFlagsInDB:(MCOIMAPMessage*)imapMessage;
- (void)updateMessageLabelsInDB:(MCOIMAPMessage*)imapMessage;

@end
