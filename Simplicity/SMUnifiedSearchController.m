//
//  SMUnifiedSearchController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 5/25/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMAppDelegate.h"
#import "SMUserAccount.h"
#import "SMAbstractLocalFolder.h"
#import "SMLocalFolderRegistry.h"
#import "SMMessageListController.h"
#import "SMUnifiedSearchController.h"

@implementation SMUnifiedSearchController

- (id)initWithUserAccount:(id<SMAbstractAccount>)account {
    self = [super initWithUserAccount:account];
    
    if(self != nil) {

    }
    
    return self;
}

- (BOOL)startNewSearchWithPattern:(NSString*)searchPattern {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    id<SMAbstractLocalFolder> searchFolder = [[_account localFolderRegistry] getLocalFolderByKind:SMFolderKindSearch];
    
    if(searchFolder == nil) {
        NSString *localName = @"__unified_search_local_folder";
        NSString *remoteName = @"__unified_search_remote_folder";
        
        searchFolder = [[_account localFolderRegistry] createLocalFolder:localName remoteFolder:remoteName kind:SMFolderKindSearch syncWithRemoteFolder:NO];
        NSAssert(searchFolder != nil, @"search folder not created");
    }

    [[_account messageListController] changeFolder:searchFolder.localName];

    BOOL result = NO;
    for(SMUserAccount *account in appDelegate.accounts) {
        if([[account searchController] startNewSearchWithPattern:searchPattern]) {
            result = YES;
        }
    }
    
    return result;
}

- (void)stopLatestSearch {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    
    for(SMUserAccount *account in appDelegate.accounts) {
        [[account searchController] stopLatestSearch];
    }
}

@end
