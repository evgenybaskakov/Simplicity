//
//  SMMessageThreadDescriptorEntry.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 10/2/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMMessageThreadDescriptorEntry.h"

@implementation SMMessageThreadDescriptorEntry

- (id)initWithFolderName:(NSString*)folderName uid:(uint32_t)uid {
    self = [super init];
    
    if(self) {
        _folderName = folderName;
        _uid = uid;
    }
    
    return self;
}

@end
