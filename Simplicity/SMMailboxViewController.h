//
//  SMMailboxViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/21/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SMFolder;
@class SMMailbox;

@interface SMMailboxViewController : NSViewController <NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate, NSMenuDelegate>

- (void)changeFolder:(SMFolder*)folder;
- (void)changeToPrevFolder;
- (void)updateFolderListView;
- (void)clearSelection;

- (NSMenu*)menuForRow:(NSInteger)row;

@end
