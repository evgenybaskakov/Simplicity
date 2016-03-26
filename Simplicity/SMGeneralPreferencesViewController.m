//
//  SMGeneralPreferencesViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/10/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

//#include <Automator/Automator.h>

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMUserAccount.h"
#import "SMPreferencesController.h"
#import "SMMessageListController.h"
#import "SMMessageListViewController.h"
#import "SMAccountsViewController.h"
#import "SMGeneralPreferencesViewController.h"

@interface SMGeneralPreferencesViewController ()

@property (weak) IBOutlet NSButton *showContactImagesInMessageListCheckBox;
@property (weak) IBOutlet NSButton *showEmailAddressesInMailboxes;
@property (weak) IBOutlet NSButton *showNotificationsCheckBox;
@property (weak) IBOutlet NSPopUpButton *messageBodyLinesPreviewList;
@property (weak) IBOutlet NSPopUpButton *messageCheckPeriodList;
@property (weak) IBOutlet NSPathControl *downloadsFolderPopup;
@property (weak) IBOutlet NSPopUpButton *defaultReplyActionList;
@property (weak) IBOutlet NSPopUpButton *preferableMessageFormatList;

@end

@implementation SMGeneralPreferencesViewController {
    NSArray *_messageListPreviewLinesNames;
    NSArray *_messageListPreviewLinesValues;
    NSArray *_messageCheckPeriodNames;
    NSArray *_messageCheckPeriodValues;
    NSArray *_defaultReplyActionNames;
    NSArray *_preferableMessageFormatNames;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //
    
    _messageListPreviewLinesNames = @[@"No preview", @"One line", @"Two lines", @"Three lines", @"Four lines"];
    _messageListPreviewLinesValues = @[@0, @1, @2, @3, @4];
    
    [_messageBodyLinesPreviewList removeAllItems];
    
    for(NSString *name in _messageListPreviewLinesNames) {
        [_messageBodyLinesPreviewList addItemWithTitle:name];
    }

    //
    
    _messageCheckPeriodNames = @[@"Auto", @"10 seconds", @"30 seconds", @"1 minute", @"2 minutes", @"5 minutes", @"10 minutes", @"20 minutes"];
    _messageCheckPeriodValues = @[@0, @10, @30, @60, @120, @300, @600, @1200];

    [_messageCheckPeriodList removeAllItems];
    
    for(NSString *name in _messageCheckPeriodNames) {
        [_messageCheckPeriodList addItemWithTitle:name];
    }

    //

    _defaultReplyActionNames = @[@"Reply All", @"Reply"];
    
    [_defaultReplyActionList removeAllItems];
    [_defaultReplyActionList addItemsWithTitles:_defaultReplyActionNames];
    
    //
    
    _preferableMessageFormatNames = @[@"HTML", @"Raw text"];
    
    [_preferableMessageFormatList removeAllItems];
    [_preferableMessageFormatList addItemsWithTitles:_preferableMessageFormatNames];
    
    // Load current properties
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

    //
    
    _showNotificationsCheckBox.state = ([[appDelegate preferencesController] shouldShowNotifications]? NSOnState : NSOffState);

    //
    
    _showContactImagesInMessageListCheckBox.state = ([[appDelegate preferencesController] shouldShowContactImages]? NSOnState : NSOffState);

    //
    
    _showEmailAddressesInMailboxes.state = ([[appDelegate preferencesController] shouldShowEmailAddressesInMailboxes]? NSOnState : NSOffState);

    //
    
    NSUInteger messageListPreviewLineCount = [[appDelegate preferencesController] messageListPreviewLineCount];
    NSUInteger currentLinesCountItem = [_messageListPreviewLinesValues indexOfObject:[NSNumber numberWithUnsignedInteger:messageListPreviewLineCount]];
    if(currentLinesCountItem == NSNotFound) {
        SM_LOG_ERROR(@"Bad messageListPreviewLineCount value %lu, using 0", messageListPreviewLineCount);
        currentLinesCountItem = 0;
    }

    [_messageBodyLinesPreviewList selectItemAtIndex:currentLinesCountItem];

    //
    
    NSUInteger messageCheckPeriodSec = [[appDelegate preferencesController] messageCheckPeriodSec];
    NSUInteger currentMessageCheckPeriodItem = [_messageCheckPeriodValues indexOfObject:[NSNumber numberWithUnsignedInteger:messageCheckPeriodSec]];
    if(currentMessageCheckPeriodItem == NSNotFound) {
        SM_LOG_ERROR(@"Bad messageCheckPeriodSec value %lu, using 0", messageCheckPeriodSec);
        currentMessageCheckPeriodItem = 0;
    }
    
    [_messageCheckPeriodList selectItemAtIndex:currentMessageCheckPeriodItem];
    
    //
    
    _downloadsFolderPopup.URL = [NSURL fileURLWithPath:[[appDelegate preferencesController] downloadsFolder]];

    [[_downloadsFolderPopup cell] setAllowedTypes:[NSArray arrayWithObject:@"public.folder"]];
    
    //
    
    switch([[appDelegate preferencesController] defaultReplyAction]) {
        case SMDefaultReplyAction_Reply:
            [_defaultReplyActionList selectItemAtIndex:1];
            break;
            
        case SMDefaultReplyAction_ReplyAll:
        default:
            [_defaultReplyActionList selectItemAtIndex:0];
            break;
    }

    //
    
    switch([[appDelegate preferencesController] preferableMessageFormat]) {
        case SMPreferableMessageFormat_HTML:
            [_preferableMessageFormatList selectItemAtIndex:0];
            break;
            
        case SMPreferableMessageFormat_RawText:
        default:
            [_preferableMessageFormatList selectItemAtIndex:1];
            break;
    }
}

- (IBAction)showContactImagesInMessageListAction:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [appDelegate preferencesController].shouldShowContactImages = (_showContactImagesInMessageListCheckBox.state == NSOnState);
    [[[appDelegate appController] messageListViewController] reloadMessageList:YES];
}

- (IBAction)showEmailAddressesInMailboxesAction:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [appDelegate preferencesController].shouldShowEmailAddressesInMailboxes = (_showEmailAddressesInMailboxes.state == NSOnState);
    [[[appDelegate appController] accountsViewController] reloadAccountViews:NO];
}

- (IBAction)showNotificationsAction:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [appDelegate preferencesController].shouldShowNotifications = (_showNotificationsCheckBox.state == NSOnState);
}

- (IBAction)messageBodyLinesPreviewListAction:(id)sender {
    NSUInteger item = _messageBodyLinesPreviewList.indexOfSelectedItem;
    NSAssert(item < _messageListPreviewLinesValues.count, @"bad item %lu", item);
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [appDelegate preferencesController].messageListPreviewLineCount = [_messageListPreviewLinesValues[item] unsignedIntegerValue];
    [[[appDelegate appController] messageListViewController] reloadMessageList:YES];
}

- (IBAction)messageCheckPeriodListAciton:(id)sender {
    NSUInteger item = _messageCheckPeriodList.indexOfSelectedItem;
    NSAssert(item < _messageCheckPeriodValues.count, @"bad item %lu", item);
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [appDelegate preferencesController].messageCheckPeriodSec = [_messageCheckPeriodValues[item] unsignedIntegerValue];

    [[appDelegate.currentAccount messageListController] scheduleMessageListUpdate:YES];
}

- (IBAction)downloadsFolderPopupAction:(id)sender {
    if(_downloadsFolderPopup.stringValue != nil) {
        SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
        [[appDelegate preferencesController] setDownloadsFolder:[_downloadsFolderPopup.URL path]];
    }
}

- (IBAction)defaultReplyAction:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    switch([_defaultReplyActionList indexOfSelectedItem]) {
        case 0:
            [[appDelegate preferencesController] setDefaultReplyAction:SMDefaultReplyAction_ReplyAll];
            break;
            
        case 1:
            [[appDelegate preferencesController] setDefaultReplyAction:SMDefaultReplyAction_Reply];
            break;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DefaultReplyActionChanged" object:nil userInfo:nil];
}

- (IBAction)preferableMessageFormatAction:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    switch([_preferableMessageFormatList indexOfSelectedItem]) {
        case 0:
            [[appDelegate preferencesController] setPreferableMessageFormat:SMPreferableMessageFormat_HTML];
            break;
            
        case 1:
            [[appDelegate preferencesController] setPreferableMessageFormat:SMPreferableMessageFormat_RawText];
            break;
    }
}

@end
