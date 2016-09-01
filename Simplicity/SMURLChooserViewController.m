//
//  SMURLChooserViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/30/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMURLChooserViewController.h"

@interface SMURLChooserViewController ()
@property (weak) IBOutlet NSTextField *promptLabel;
@property (weak) IBOutlet NSButton *browseFileButton;
@property (weak) IBOutlet NSButton *okButton;
@property (weak) IBOutlet NSButton *cancelButton;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;
@end

@implementation SMURLChooserViewController {
    NSOpenPanel *_fileDlg;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _okButton.enabled = NO;
    _cancelButton.enabled = YES;
    _progressIndicator.hidden = YES;
}

- (IBAction)urlTextFieldAction:(id)sender {
    NSLog(@"urlTextFieldAction");
}

- (IBAction)browseFileButtonAction:(id)sender {
    if(_fileDlg == nil) {
        _fileDlg = [NSOpenPanel openPanel];
        
        [_fileDlg setCanChooseFiles:YES];
        [_fileDlg setCanChooseDirectories:NO];
        [_fileDlg setPrompt:@"Choose image file"];
        [_fileDlg setAllowedFileTypes:[NSImage imageTypes]];
        [_fileDlg setAllowsOtherFileTypes:NO];
        [_fileDlg setAllowsMultipleSelection:NO];
    }

    [_fileDlg beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger result) {
        NSArray<NSURL*>* files = [_fileDlg URLs];
        for(NSURL* url in files) {
            NSImage *img = nil;
            if(url) {
                img = [[NSImage alloc]initWithContentsOfURL:url];
            }
            
            if(img) {
                _chosenImage = img;
                _urlTextField.stringValue = url.absoluteString;
                _okButton.enabled = YES;
                
                if(_target && _actionProbe) {
                    [_target performSelectorOnMainThread:_actionProbe withObject:self waitUntilDone:NO];
                }

                break;
            }
        }
        
        [_fileDlg close];
    }];
 
//    [_fileDlg makeKeyAndOrderFront:self];
}

- (IBAction)okButtonAction:(id)sender {
    if(_target && _actionOk) {
        [_target performSelectorOnMainThread:_actionOk withObject:self waitUntilDone:NO];
    }
}

- (IBAction)cancelButtonAction:(id)sender {
    if(_target && _actionCancel) {
        [_target performSelectorOnMainThread:_actionCancel withObject:self waitUntilDone:NO];
    }
}

@end
