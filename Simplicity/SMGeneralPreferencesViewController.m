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
#import "SMPreferencesController.h"
#import "SMMessageListController.h"
#import "SMMessageListViewController.h"
#import "SMGeneralPreferencesViewController.h"

@interface SMGeneralPreferencesViewController ()

@property (weak) IBOutlet NSButton *showContactImagesInMessageListCheckBox;
@property (weak) IBOutlet NSPopUpButton *messageBodyLinesPreviewList;
@property (weak) IBOutlet NSPopUpButton *messageCheckPeriodList;
@property (weak) IBOutlet NSPathControl *downloadsFolderPopup;
@property (weak) IBOutlet NSPopUpButton *defaultReplyActionList;

@end

@implementation SMGeneralPreferencesViewController {
    NSArray *_messageListPreviewLinesNames, *_messageListPreviewLinesValues;
    NSArray *_messageCheckPeriodNames, *_messageCheckPeriodValues;
    NSArray *_defaultReplyActionNames;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    
    _messageListPreviewLinesNames = @[@"No preview", @"One line", @"Two lines", @"Three lines", @"Four lines"];
    _messageListPreviewLinesValues = @[@0, @1, @2, @3, @4];
    
    [_messageBodyLinesPreviewList removeAllItems];
    
    for(NSString *name in _messageListPreviewLinesNames) {
        [_messageBodyLinesPreviewList addItemWithTitle:name];
    }

    _messageCheckPeriodNames = @[@"Auto", @"1 minute", @"2 minutes", @"5 minutes", @"10 minutes", @"20 minutes", @"30 minutes", @"1 hour"];
    _messageCheckPeriodValues = @[@0, @60, @120, @300, @600, @1200, @1800, @3600];

    [_messageCheckPeriodList removeAllItems];
    
    for(NSString *name in _messageCheckPeriodNames) {
        [_messageCheckPeriodList addItemWithTitle:name];
    }
    
    _defaultReplyActionNames = @[@"Reply All", @"Reply"];
    
    [_defaultReplyActionList removeAllItems];
    [_defaultReplyActionList addItemsWithTitles:_defaultReplyActionNames];

    // Load current properties
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

    //
    
    _showContactImagesInMessageListCheckBox.state = ([[appDelegate preferencesController] shouldShowContactImages]? NSOnState : NSOffState);

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
}

- (IBAction)showContactImagesInMessageListAction:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [appDelegate preferencesController].shouldShowContactImages = (_showContactImagesInMessageListCheckBox.state == NSOnState);
    [[[appDelegate appController] messageListViewController] reloadMessageList:YES];
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

    [[[appDelegate model] messageListController] scheduleMessageListUpdate:YES];
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

@end
