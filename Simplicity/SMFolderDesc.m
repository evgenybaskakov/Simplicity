//
//  SMFolderDesc.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/20/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMFolderDesc.h"

@implementation SMFolderDesc

- (id)initWithFolderName:(NSString*)folderName delimiter:(char)delimiter flags:(MCOIMAPFolderFlag)flags {
    self = [super init];
    
    if(self) {
        _folderName = folderName;
        _delimiter = delimiter;
        _flags = flags;
    }
    
    return self;
}

@end
