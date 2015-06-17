//
//  SMAttachmentsPanelViewContoller.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 1/23/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMAttachmentItem.h"
#import "SMAttachmentsPanelViewController.h"

@implementation SMAttachmentsPanelViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	
	if(self) {
		_attachmentItems = [[NSMutableArray alloc] init];
	}
	
	return self;
}

- (void)viewDidLoad {
    NSLog(@"%s", __func__);
    
    NSAssert(_collectionView, @"no collection view");
    
    NSArray *supportedTypes = [NSArray arrayWithObjects:@"com.simplicity.attachment.collection.item", NSFilenamesPboardType, nil];

    [_collectionView registerForDraggedTypes:supportedTypes];
    [_collectionView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];
}

- (BOOL)collectionView:(NSCollectionView *)collectionView canDragItemsAtIndexes:(NSIndexSet *)indexes withEvent:(NSEvent *)event {
	NSLog(@"%s: indexes %@", __func__, indexes);

	return YES;
}

-(BOOL)collectionView:(NSCollectionView *)collectionView writeItemsAtIndexes:(NSIndexSet *)indexes toPasteboard:(NSPasteboard *)pasteboard {
	NSLog(@"%s: indexes %@", __func__, indexes);

	[pasteboard declareTypes:[NSArray arrayWithObject:NSFilesPromisePboardType] owner:self];

	NSMutableArray *fileExtensions = [NSMutableArray array];
	
	for(NSUInteger i = [indexes firstIndex]; i != NSNotFound; i = [indexes indexGreaterThanIndex:i]) {
		SMAttachmentItem *item = _attachmentItems[i];
		[fileExtensions addObject:[item.fileName pathExtension]];
	}

	[pasteboard setPropertyList:fileExtensions forType:NSFilesPromisePboardType];
	
	return YES;
}

 - (NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context {
	switch(context) {
		case NSDraggingContextOutsideApplication:
			return NSDragOperationCopy;
			
		case NSDraggingContextWithinApplication:
			return NSDragOperationCopy; // TODO: composing message with attachments
			
		default:
			return NSDragOperationCopy;
	}
}

- (void)insertFiles:(NSArray *)files atIndex:(NSInteger)index
{
/*
 NSMutableArray *insertedObjects = [NSMutableArray array];
 */
    NSArrayController *arrayController = _arrayController;
    
    for (NSURL *url in files)
    {
        // add file to our bundle
        NSLog(@"%s: addFileWithPath:%@", __func__, [url path]);

        [arrayController addObject:[[SMAttachmentItem alloc] initWithFilePath:[url path]]];

//        [arrayController addObject:[[SMAttachmentItem alloc] initWithMessage:_message attachmentIndex:i]];
        

/*
 // create model object for it
        DocumentItem *newItem = [[DocumentItem alloc] init];
        newItem.fileName = [[URL path] lastPathComponent];
        newItem.document = self;
        
        // add to our items
        [insertedObjects addObject:newItem];
*/
    }

    [arrayController setSelectedObjects:[NSArray array]];

/*
 // send KVO message so that the array controller updates itself
    [self willChangeValueForKey:@"items"];
    [self.items insertObjects:insertedObjects atIndexes:[NSIndexSet indexSetWithIndex:index]];
    [self didChangeValueForKey:@"items"];
    
    // mark document as dirty
    [self updateChangeCount:NSChangeDone];
*/
}

- (BOOL)collectionView:(NSCollectionView *)collectionView acceptDrop:(id<NSDraggingInfo>)draggingInfo index:(NSInteger)index dropOperation:(NSCollectionViewDropOperation)dropOperation {

    NSLog(@"%s: TODO", __func__);

    NSPasteboard *pasteboard = [draggingInfo draggingPasteboard];
    
    NSMutableArray *files = [NSMutableArray array];
    
    for (NSPasteboardItem *oneItem in [pasteboard pasteboardItems])
    {
        NSString *urlString = [oneItem stringForType:(id)kUTTypeFileURL];
        NSURL *URL = [NSURL URLWithString:urlString];
        
        if (URL)
        {
            [files addObject:URL];
        }
    }
    
    if ([files count])
    {
        [self insertFiles:files atIndex:index];
    }

    return YES;
}

-(NSDragOperation)collectionView:(NSCollectionView *)collectionView validateDrop:(id<NSDraggingInfo>)draggingInfo proposedIndex:(NSInteger *)proposedDropIndex dropOperation:(NSCollectionViewDropOperation *)proposedDropOperation {
	// do not recognize any drop to itself
	// TODO: may need to add logic for messages being composed

    if (!draggingInfo.draggingSource)
    {
        NSLog(@"%s: TODO (external)", __func__);

        // comes from external
        return NSDragOperationCopy;
    }
    
    NSLog(@"%s: TODO (internal)", __func__);
    
    // comes from internal
    return NSDragOperationMove;
}

- (NSArray *)collectionView:(NSCollectionView *)collectionView namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropURL forDraggedItemsAtIndexes:(NSIndexSet *)indexes {
	NSLog(@"%s: indexes %@, drop url %@", __func__, indexes, dropURL);

	NSMutableArray *fileNames = [NSMutableArray array];

	for(NSUInteger i = [indexes firstIndex]; i != NSNotFound; i = [indexes indexGreaterThanIndex:i]){
		SMAttachmentItem *item = _attachmentItems[i];

		// TODO: overwriting?
		[item writeAttachmentTo:dropURL];
		[fileNames addObject:item.fileName];
	}

	return fileNames;
}

#pragma mark Dragging destination

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
    NSLog(@"%s: TODO", __func__);
    return [self draggingEntered:sender];
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender {
    NSLog(@"%s: TODO", __func__);
    return [self draggingUpdated:sender];
}

//- (void)draggingExited:(id <NSDraggingInfo>)sender {
//}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender {
    return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
    return YES;
}

//- (void)concludeDragOperation:(id <NSDraggingInfo>)sender {
//}

//- (void)draggingEnded:(id <NSDraggingInfo>)sender {
//}

@end
