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
#import "SMMessageListViewController.h"
#import "SMGeneralPreferencesViewController.h"

@interface SMGeneralPreferencesViewController ()

@property (weak) IBOutlet NSButton *showContactImagesInMessageListCheckBox;
@property (weak) IBOutlet NSPopUpButton *messageBodyLinesPreviewList;
@property (weak) IBOutlet NSPopUpButton *messageCheckPeriodList;
//@property (weak) IBOutlet AMPathPopUpButton *downloadsFolderPopup;

@end

@implementation SMGeneralPreferencesViewController {
    NSArray *_previewLinesNames;
    NSArray *_previewLinesValues;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    
    _previewLinesNames = @[@"No preview", @"One line", @"Two lines", @"Three lines", @"Four lines"];
    _previewLinesValues = @[@0, @1, @2, @3, @4];
    
    [_messageBodyLinesPreviewList removeAllItems];
    
    for(NSString *name in _previewLinesNames) {
        [_messageBodyLinesPreviewList addItemWithTitle:name];
    }

    [_messageCheckPeriodList removeAllItems];
    [_messageCheckPeriodList addItemWithTitle:@"30 seconds"];
    [_messageCheckPeriodList addItemWithTitle:@"1 minute"];
    [_messageCheckPeriodList addItemWithTitle:@"2 minutes"];
    [_messageCheckPeriodList addItemWithTitle:@"5 minutes"];
    [_messageCheckPeriodList addItemWithTitle:@"10 minutes"];
    [_messageCheckPeriodList addItemWithTitle:@"20 minutes"];
    [_messageCheckPeriodList addItemWithTitle:@"30 minutes"];
    [_messageCheckPeriodList addItemWithTitle:@"1 hour"];

    // Load current properties
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

    _showContactImagesInMessageListCheckBox.state = ([[appDelegate preferencesController] shouldShowContactImages]? NSOnState : NSOffState);

    NSUInteger currentLinesCountItem = [[appDelegate preferencesController] messageListPreviewLineCount];
    if(currentLinesCountItem >= _previewLinesNames.count) {
        SM_LOG_ERROR(@"Bad messageListPreviewLineCount value %lu, using 0", currentLinesCountItem);
        currentLinesCountItem = 0;
    }

    [_messageBodyLinesPreviewList selectItemAtIndex:currentLinesCountItem];
}

- (IBAction)showContactImagesInMessageListAction:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [appDelegate preferencesController].shouldShowContactImages = (_showContactImagesInMessageListCheckBox.state == NSOnState);
    [[[appDelegate appController] messageListViewController] reloadMessageList:YES];
}

- (IBAction)messageBodyLinesPreviewListAction:(id)sender {
    NSUInteger currentLinesCountItem = _messageBodyLinesPreviewList.indexOfSelectedItem;
    NSAssert(currentLinesCountItem < _previewLinesValues.count, @"bad currentLinesCountItem %lu", currentLinesCountItem);
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [appDelegate preferencesController].messageListPreviewLineCount = [_previewLinesValues[currentLinesCountItem] unsignedIntegerValue];
    [[[appDelegate appController] messageListViewController] reloadMessageList:YES];
}

- (IBAction)messageCheckPeriodListAciton:(id)sender {
    SM_LOG_WARNING(@"TODO");
}

- (IBAction)downloadsFolderPopupAction:(id)sender {
    SM_LOG_WARNING(@"TODO");
}

@end
