//
//  SMSignaturePreferencesViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/20/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <WebKit/WebEditingDelegate.h>
#import <Cocoa/Cocoa.h>

@interface SMSignaturePreferencesViewController : NSViewController<WebEditingDelegate>

- (void)reloadAccountSignatures;

@end
