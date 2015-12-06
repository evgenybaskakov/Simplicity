//
//  SMNotificationsController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 12/5/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMAppDelegate.h"
#import "SMPreferencesController.h"
#import "SMNotificationsController.h"

@implementation SMNotificationsController

+ (void)notifyNewMessage:(NSString*)from {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMPreferencesController *preferencesController = [appDelegate preferencesController];
    
    if(preferencesController.shouldShowNotifications) {
        NSUserNotification *notification = [[NSUserNotification alloc] init];

        notification.title = @"New message";
        notification.informativeText = [NSString stringWithFormat:@"From %@", from];
        notification.soundName = NSUserNotificationDefaultSoundName;
        
        [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
    }
}

+ (void)notifyNewMessages:(NSUInteger)count {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    SMPreferencesController *preferencesController = [appDelegate preferencesController];
    
    if(preferencesController.shouldShowNotifications) {
        NSUserNotification *notification = [[NSUserNotification alloc] init];
        
        notification.title = [NSString stringWithFormat:@"%lu new messages", count];
//        notification.informativeText = previewText;
        notification.soundName = NSUserNotificationDefaultSoundName;
        
        [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
    }
}

@end
