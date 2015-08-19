//
//  SMNewLabelWindowController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/5/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMSimplicityContainer.h"
#import "SMMailbox.h"
#import "SMMailboxController.h"
#import "SMFolder.h"
#import "SMFolderColorController.h"
#import "SMNewLabelWindowController.h"

@implementation SMNewLabelWindowController

- (IBAction)createAction:(id)sender {
	NSString *folderName = _labelName.stringValue;
	NSString *parentFolderName = _labelNestedCheckbox.state == NSOnState? _nestingLabelName.titleOfSelectedItem : nil;
	
	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	SMMailboxController *mailboxController = [[appDelegate model] mailboxController];

	NSString *fullFolderName = [mailboxController createFolder:folderName parentFolder:parentFolderName];
	if(fullFolderName != nil) {
		
		// TODO: sophisticated error handling
		
		SMFolderColorController *folderColorController = [[appDelegate appController] folderColorController];
		[folderColorController setFolderColor:fullFolderName color:_labelColorWell.color];
	}

	[self closeNewLabelWindow];
}

- (IBAction)cancelAction:(id)sender {
	[self closeNewLabelWindow];
}

- (IBAction)toggleNestedLabelAction:(id)sender {
	const Boolean nestLabel = (_labelNestedCheckbox.state == NSOnState);

	[_nestingLabelName setEnabled:nestLabel];
}

- (void)windowWillClose:(NSNotification *)notification {
    [self closeNewLabelWindow];
}

- (void)closeNewLabelWindow {
	[_labelColorWell deactivate];
	[[NSColorPanel sharedColorPanel] orderOut:nil];
	
	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	[[appDelegate appController] hideNewLabelSheet];
}

- (void)updateExistingLabelsList {
	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	SMMailbox *mailbox = [[appDelegate model] mailbox];

	NSMutableArray *labelsList = [NSMutableArray array];
	for(SMFolder *folder in mailbox.folders)
		[labelsList addObject:folder.fullName];

	[_nestingLabelName removeAllItems];
	[_nestingLabelName addItemsWithTitles:labelsList];
}

- (void)setSuggestedNestingLabel:(NSString*)nestingLabel {
	if(nestingLabel != nil) {
		[_nestingLabelName selectItemWithTitle:nestingLabel];
		[_nestingLabelName setEnabled:YES];
		[_labelNestedCheckbox setState:NSOnState];
	} else {
		[_nestingLabelName setEnabled:NO];
		[_labelNestedCheckbox setState:NSOffState];
	}
}

@end
