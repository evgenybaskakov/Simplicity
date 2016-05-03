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

@class SMLocalFolder;
@class SMMessage;

@interface SMMessageListController : SMUserAccountDataObject

- (id)initWithUserAccount:(SMUserAccount*)account;
- (void)changeFolder:(NSString*)folder;
- (void)changeToPrevFolder;
- (void)clearCurrentFolderSelection;
- (SMLocalFolder*)currentLocalFolder;
- (void)fetchMessageBodyUrgently:(uint32_t)uid messageDate:(NSDate*)messageDate remoteFolder:(NSString*)remoteFolderName threadId:(uint64_t)threadId;
- (void)loadSearchResults:(MCOIndexSet*)searchResults remoteFolderToSearch:(NSString*)remoteFolderNameToSearch searchResultsLocalFolder:(NSString*)searchResultsLocalFolder updateResults:(BOOL)updateResults;
- (void)scheduleMessageListUpdate:(Boolean)now;
- (void)cancelScheduledMessageListUpdate;
- (void)cancelMessageListUpdate;

@end
