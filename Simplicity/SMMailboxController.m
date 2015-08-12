//
//  SMMailboxController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 7/4/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMSimplicityContainer.h"
#import "SMMailbox.h"
#import "SMMailboxController.h"

#define FOLDER_LIST_UPDATE_INTERVAL_SEC 5

@implementation SMMailboxController {
	__weak SMSimplicityContainer *_model;
	MCOIMAPFetchFoldersOperation *_fetchFoldersOp;
	MCOIMAPOperation *_createFolderOp;
	MCOIMAPOperation *_renameFolderOp;
}

- (id)initWithModel:(SMSimplicityContainer*)model {
	self = [ super init ];
	
	if(self) {
		_model = model;
	}
	
	return self;
}

- (void)scheduleFolderListUpdate:(Boolean)now {
	//NSLog(@"%s: scheduling folder update after %u sec", __func__, FOLDER_LIST_UPDATE_INTERVAL_SEC);

	[self stopFolderListUpdate];

	[self performSelector:@selector(updateFolders) withObject:nil afterDelay:now? 0 : FOLDER_LIST_UPDATE_INTERVAL_SEC];
}

- (void)stopFolderListUpdate {
	[_fetchFoldersOp cancel];
	_fetchFoldersOp = nil;

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateFolders) object:nil];
}

- (void)updateFolders {
	//NSLog(@"%s: updating folders", __func__);

	MCOIMAPSession *session = [ _model imapSession ];
	NSAssert(session != nil, @"session is nil");

	if(_fetchFoldersOp == nil)
		_fetchFoldersOp = [session fetchAllFoldersOperation];
	
	[_fetchFoldersOp start:^(NSError * error, NSArray *folders) {
		_fetchFoldersOp = nil;
		
		// schedule now to keep the folder list updated
		// regardless of any connectivity or server errors
		[self scheduleFolderListUpdate:NO];
		
		if (error != nil && [error code] != MCOErrorNone) {
			NSLog(@"Error downloading folders structure: %@", error);
			return;
		}
		
		SMMailbox *mailbox = [ _model mailbox ];
		NSAssert(mailbox != nil, @"mailbox is nil");

		if([mailbox updateIMAPFolders:folders]) {
			SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
			SMAppController *appController = [appDelegate appController];

			[appController performSelectorOnMainThread:@selector(updateMailboxFolderList) withObject:nil waitUntilDone:NO];
		}
	}];
}

- (NSString*)createFolder:(NSString*)folderName parentFolder:(NSString*)parentFolderName {
	SMMailbox *mailbox = [ _model mailbox ];
	NSAssert(mailbox != nil, @"mailbox is nil");

	MCOIMAPSession *session = [ _model imapSession ];
	NSAssert(session != nil, @"session is nil");

	NSString *fullFolderName = [mailbox constructFolderName:folderName parent:parentFolderName];
	if(fullFolderName == nil)
		return nil;
	
	NSAssert(_createFolderOp == nil, @"another create folder op exists");
	_createFolderOp = [session createFolderOperation:fullFolderName];

	[_createFolderOp start:^(NSError * error) {
		_createFolderOp = nil;
		
		if (error != nil && [error code] != MCOErrorNone) {
			NSLog(@"Error creating folder %@: %@", fullFolderName, error);
		} else {
			NSLog(@"Folder %@ created", fullFolderName);

			SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
			[[[appDelegate model] mailboxController] scheduleFolderListUpdate:YES];
		}
	}];
	
	return fullFolderName;
}

- (void)renameFolder:(NSString*)oldFolderName newFolderName:(NSString*)newFolderName {
	if([oldFolderName isEqualToString:newFolderName])
		return;

	SMMailbox *mailbox = [ _model mailbox ];
	NSAssert(mailbox != nil, @"mailbox is nil");
	
	[mailbox removeFavoriteFolderWithName:oldFolderName];
	
	MCOIMAPSession *session = [ _model imapSession ];
	NSAssert(session != nil, @"session is nil");
	
	NSAssert(_renameFolderOp == nil, @"another create folder op exists");
	_renameFolderOp = [session renameFolderOperation:oldFolderName otherName:newFolderName];
	
	[_renameFolderOp start:^(NSError * error) {
		_renameFolderOp = nil;

		if (error != nil && [error code] != MCOErrorNone) {
			NSLog(@"Error renaming folder %@ to %@: %@", oldFolderName, newFolderName, error);
		} else {
			NSLog(@"Folder %@ renamed to %@", oldFolderName, newFolderName);

			SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
			[[[appDelegate model] mailboxController] scheduleFolderListUpdate:YES];
		}
	}];
}

@end
