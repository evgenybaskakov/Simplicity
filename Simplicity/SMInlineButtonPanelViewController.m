//
//  SMInlineButtonPanelViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/3/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMInlineButtonPanelViewController.h"

@implementation SMInlineButtonPanelViewController {
    __weak id _target;
    SEL _action;
}

- (void)viewDidLoad {
    NSMutableAttributedString *attrTitle = [[NSMutableAttributedString alloc] initWithString:_button.title];
    NSUInteger len = [attrTitle length];
    NSRange range = NSMakeRange(0, len);
    
    [attrTitle addAttribute:NSForegroundColorAttributeName value:[NSColor blueColor] range:range];
    [attrTitle fixAttributesInRange:range];
    
    [_button setAttributedTitle:attrTitle];
}

- (void)buttonClicked:(id)sender {
    id target = _target;
    
    if(target != nil) {
        [target performSelector:_action withObject:nil afterDelay:0.0];
    }
}

- (void)setButtonTarget:(id)target action:(SEL)action {
    _target = target;
    _action = action;
}

@end
