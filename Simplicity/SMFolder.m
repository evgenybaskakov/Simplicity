//
//  SMFolder.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/23/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import "SMFolder.h"

@implementation SMFolder {
    NSString *_fullName;
    NSString *_displayName;
}

- (id)initWithFullName:(NSString*)fullName delimiter:(char)delimiter mcoFlags:(MCOIMAPFolderFlag)mcoFlags kind:(SMFolderKind)kind {
    self = [ super init ];
    
    if(self) {
        _fullName = fullName;
        _delimiter = delimiter;
        _mcoFlags = mcoFlags;
        _kind = kind;
    }
    
    return self;
}

- (id)initWithFullName:(NSString*)fullName delimiter:(char)delimiter mcoFlags:(MCOIMAPFolderFlag)mcoFlags {
    return [self initWithFullName:fullName delimiter:delimiter mcoFlags:mcoFlags kind:SMFolderKindRegular];
}

- (void)setDisplayName:(NSString *)displayName {
    _displayName = displayName;
}

- (NSString *)displayName {
    return _displayName != nil? _displayName : _fullName;
}

@end
