//
//  SMTokenField.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 10/12/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import "SMTokenField.h"

@implementation SMTokenField {
	CGFloat _height;
}

// See these topics for explanation:
//
// http://stackoverflow.com/questions/10463680/how-to-let-nstextfield-grow-with-the-text-in-auto-layout
// http://stackoverflow.com/questions/24618703/automatically-wrap-nstextfield-using-auto-layout
// http://stackoverflow.com/questions/3212279/nstableview-row-height-based-on-nsstrings

static BOOL floats_equal(CGFloat a, CGFloat b) {
	return fabs(a - b) < 0.00001;
}

-(NSSize)intrinsicContentSize
{
	if(![self.cell wraps])
		return [super intrinsicContentSize];

	NSRect frame = [self frame];
	
	frame.size.height = CGFLOAT_MAX;
	
	NSSize sizeToFit = [self.cell cellSizeForBounds:frame];

	// TODO: all this looks like a big ugly hack - must be fixed
	if(!floats_equal(_height, sizeToFit.height)) {
		_height = sizeToFit.height;

		// TODO: not sure if this is an appropriate place to do the intrinsic size invalidation
        NSLog(@"%s",__func__);
        
//        self.frame = NSMakeRect(self.frame.origin.x, self.frame.origin.y, self.frame.size.width, _height);

        [[NSNotificationCenter defaultCenter] postNotificationName:@"SMTokenFieldHeightChanged" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:self, @"Object", nil]];

		[self invalidateIntrinsicContentSize];
		[self.superview invalidateIntrinsicContentSize];
	}
	
	return NSMakeSize(-1, sizeToFit.height);
}

- (void)textDidChange:(NSNotification *)notification
{
	NSLog(@"%s", __func__);

	[super textDidChange:notification];
	[self invalidateIntrinsicContentSize];
}

- (void)viewDidEndLiveResize
{
	NSLog(@"%s", __func__);

	[super viewDidEndLiveResize];
	[self invalidateIntrinsicContentSize];
}

@end
