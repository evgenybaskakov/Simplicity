//
//  SMFolderIdleController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 12/9/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SMLocalFolder;
@class SMFolderUpdateController;

@interface SMFolderIdleController : NSObject

@property (readonly) SMLocalFolder *watchedFolder;

- (id)initWithUserAccount:(SMUserAccount*)account folder:(SMLocalFolder*)folder updateController:(SMFolderUpdateController*)updateController;

- (void)startIdle;
- (void)stopIdle;
- (void)stopReachabilityMonitor;

@end
