//
//  SMMessageThreadDescriptorEntry.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 10/2/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SMMessageThreadDescriptorEntry : NSObject

@property (readonly) NSString *folderName;
@property (readonly) uint32_t uid;

- (id)initWithFolderName:(NSString*)folderName uid:(uint32_t)uid;

@end
