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
#import "SMNotificationsController.h"
#import "SMSimplicityContainer.h"
#import "SMMailbox.h"
#import "SMMailboxController.h"
#import "SMFolder.h"
#import "SMFolderColorController.h"
#import "SMNewLabelWindowController.h"

@implementation SMNewLabelWindowController {
    NSString *_nestingLabel;
}

- (void)windowDidBecomeMain:(NSNotification *)notification {
    [self updateExistingLabelsList];
    [self updateSuggestedNestingLabel];
}

- (IBAction)createAction:(id)sender {
    NSString *folderName = _labelName.stringValue;
    NSString *parentFolderName = _labelNestedCheckbox.state == NSOnState? _nestingLabelNameButton.titleOfSelectedItem : nil;
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMMailboxController *mailboxController = [[appDelegate model] mailboxController];

    NSString *fullFolderName = [mailboxController createFolder:folderName parentFolder:parentFolderName];
    if(fullFolderName != nil) {
        
        // TODO: sophisticated error handling
        
        SMFolderColorController *folderColorController = [[appDelegate appController] folderColorController];
        [folderColorController setFolderColor:fullFolderName color:_labelColorWell.color];
        
        [mailboxController scheduleFolderListUpdate:YES];
        
        [SMNotificationsController localNotifyNewLabelCreated:fullFolderName];
    }

    [self closeNewLabelWindow];
}

- (IBAction)cancelAction:(id)sender {
    [self closeNewLabelWindow];
}

- (IBAction)toggleNestedLabelAction:(id)sender {
    const Boolean nestLabel = (_labelNestedCheckbox.state == NSOnState);

    [_nestingLabelNameButton setEnabled:nestLabel];
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

    [_nestingLabelNameButton removeAllItems];
    [_nestingLabelNameButton addItemsWithTitles:labelsList];
}

- (void)updateSuggestedNestingLabel {
    if(_suggestedNestingLabel != nil) {
        [_nestingLabelNameButton selectItemWithTitle:_suggestedNestingLabel];
        [_nestingLabelNameButton setEnabled:YES];
        [_labelNestedCheckbox setState:NSOnState];

        SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
        NSColor *nestingColor = [[[appDelegate appController] folderColorController] colorForFolder:_suggestedNestingLabel];
        
        if(nestingColor != nil) {
            _labelColorWell.color = nestingColor;
        }
        else {
            _labelColorWell.color = [SMFolderColorController randomLabelColor];
        }
    }
    else {
        [_nestingLabelNameButton setEnabled:NO];
        [_labelNestedCheckbox setState:NSOffState];

        _labelColorWell.color = [SMFolderColorController randomLabelColor];
    }
}

@end
