//
//  SMMailboxViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/21/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SMMailbox;

@interface SMMailboxViewController : NSViewController <NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate, NSMenuDelegate>

@property (weak) IBOutlet NSTableView *folderListView;
@property (readonly) NSString *currentFolderName;

- (void)changeFolder:(NSString*)folderName;
- (void)changeToPrevFolder;
- (void)updateFolderListView;
- (void)clearSelection;

- (NSMenu*)menuForRow:(NSInteger)row;

@end
