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

@implementation SMGeneralPreferencesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    
    [_messageBodyLinesPreviewList removeAllItems];
    [_messageBodyLinesPreviewList addItemWithTitle:@"No preview"];
    [_messageBodyLinesPreviewList addItemWithTitle:@"One line"];
    [_messageBodyLinesPreviewList addItemWithTitle:@"Two lines"];
    [_messageBodyLinesPreviewList addItemWithTitle:@"Three lines"];
    [_messageBodyLinesPreviewList addItemWithTitle:@"Four lines"];

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

//    [_downloadsFolderPopup ];
}

- (IBAction)showContactImagesInMessageListAction:(id)sender {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    
    [appDelegate preferencesController].shouldShowContactImages = (_showContactImagesInMessageListCheckBox.state == NSOnState);
    
    [[[appDelegate appController] messageListViewController] reloadMessageList:YES];
}

- (IBAction)messageBodyLinesPreviewListAction:(id)sender {
    SM_LOG_WARNING(@"TODO");
}

- (IBAction)messageCheckPeriodListAciton:(id)sender {
    SM_LOG_WARNING(@"TODO");
}

- (IBAction)downloadsFolderPopupAction:(id)sender {
    SM_LOG_WARNING(@"TODO");
}

@end
