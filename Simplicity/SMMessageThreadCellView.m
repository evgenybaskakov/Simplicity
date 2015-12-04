//
//  SMMessageThreadCellView.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/2/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import "SMMessageViewController.h"
#import "SMMessageThreadCellView.h"

@implementation SMMessageThreadCellView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)awakeFromNib {
    _messageViewController = [[SMMessageViewController alloc] initWithNibName:@"SMMessageViewController" bundle:nil ];
    
    NSAssert(_messageViewController, @"_messageViewController");
    
    NSView *messageView = [ _messageViewController view ];
    
    NSAssert(messageView, @"messageView");
    NSAssert(_messageView, @"_messageView");
    
    [ _messageView addSubview:messageView ];
    
    NSRect bounds = [ _messageView bounds ];
    [ messageView setFrame:bounds ];

    _headerButton.target = self;
    _headerButton.action = @selector(buttonClicked:);
}

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
    
    // Drawing code here.
    [_messageView drawRect:dirtyRect];
}

- (void)buttonClicked:(id)sender {
    const Boolean messageViewWasHidden = [_messageView isHidden];
    
    // TODO: apply shown/hidden properties on first thread creation
    [_messageView setHidden:!messageViewWasHidden];
}

@end
