//
//  SMMessageListUpdater.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/12/13.
//  Copyright (c) 2013 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <MailCore/MailCore.h>

#import "SMUserAccountDataObject.h"

@protocol SMAbstractLocalFolder;

@class SMMessage;
@class SMMessageThread;
@class SMLocalFolder;

@interface SMMessageListController : SMUserAccountDataObject

- (id)initWithUserAccount:(id<SMAbstractAccount>)account;
- (void)changeFolder:(NSString*)folder clearSearch:(BOOL)clearSearch;
- (void)changeToPrevFolder;
- (void)clearCurrentFolderSelection;
- (id<SMAbstractLocalFolder>)currentLocalFolder;
- (void)fetchMessageInlineAttachments:(SMMessage*)message messageThread:(SMMessageThread*)messageThread;
- (void)fetchMessageBodyUrgently:(uint32_t)uid messageDate:(NSDate*)messageDate remoteFolder:(NSString*)remoteFolderName messageThread:(SMMessageThread*)messageThread;
- (void)loadSearchResults:(MCOIndexSet*)searchResults remoteFolderToSearch:(NSString*)remoteFolderNameToSearch searchResultsLocalFolder:(NSString*)searchResultsLocalFolder changeFolder:(BOOL)changeFolder;
- (void)scheduleMessageListUpdate:(Boolean)now;
- (void)cancelScheduledMessageListUpdate;
- (BOOL)localFolderIsCurrent:(SMLocalFolder*)localFolder;

@end
