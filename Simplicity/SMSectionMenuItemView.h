//
//  SMSuggestionsMenuRowView.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 1/18/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SMSectionMenuViewController;

@interface SMSectionMenuItemView : NSTableCellView

@property __weak SMSectionMenuViewController *parentMenuViewController;

@end
