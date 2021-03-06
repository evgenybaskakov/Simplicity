//
//  SMAccountsViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/11/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#include "SMPreferencesController.h"

@interface SMAccountsViewController : NSViewController

@property (nonatomic) SMMailboxTheme mailboxTheme;

- (void)changeAccountTo:(NSInteger)accountIdx;
- (void)reloadAccountViews:(BOOL)reloadControllers;

@end
