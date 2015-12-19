//
//  SMFolderLabel.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 12/13/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMFolderLabel.h"

@implementation SMFolderLabel

- (id)initWithName:(NSString*)name color:(NSColor*)color favorite:(BOOL)favorite visible:(BOOL)visible {
    self = [super init];
    
    if(self) {
        _name = name;
        _color = color;
        _favorite = favorite;
        _visible = visible;
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super init];
    
    if(self) {
        _name = [coder decodeObjectForKey:@"_name"];
        _color = [coder decodeObjectForKey:@"_color"];
        _favorite = [coder decodeBoolForKey:@"_favorite"];
        _visible = [coder decodeBoolForKey:@"_visible"];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_name forKey:@"_name"];
    [coder encodeObject:_color forKey:@"_color"];
    [coder encodeBool:_favorite forKey:@"_favorite"];
    [coder encodeBool:_visible forKey:@"_visible"];
}

@end
