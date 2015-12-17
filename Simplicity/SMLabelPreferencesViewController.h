//
//  SMLabelPreferencesViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 12/13/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SMLabelPreferencesViewController : NSViewController<NSTableViewDataSource, NSTableViewDelegate>

- (void)reloadAccountLabels;

@end
