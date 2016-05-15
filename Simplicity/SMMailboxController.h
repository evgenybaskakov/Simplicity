//
//  SMMailboxController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 4/29/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SMFolder;

@protocol SMMailboxController<NSObject>

@property (readonly) SMFolder *selectedFolder;

- (void)initFolders;
- (NSString*)createFolder:(NSString*)folderName parentFolder:(NSString*)parentFolderName;
- (void)renameFolder:(NSString*)oldFolderName newFolderName:(NSString*)newFolderName;
- (void)deleteFolder:(NSString*)oldFolderName;
- (void)changeFolder:(SMFolder*)folder;
- (NSUInteger)unseenMessagesCount:(SMFolder*)folder;
- (NSUInteger)totalMessagesCount:(SMFolder*)folder;

@end
