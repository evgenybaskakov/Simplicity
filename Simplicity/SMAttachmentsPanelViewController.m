//
//  SMAttachmentsPanelViewContoller.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 1/23/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMMessage.h"
#import "SMAttachmentItem.h"
#import "SMMessageEditorController.h"
#import "SMAttachmentsPanelView.h"
#import "SMAttachmentsPanelViewController.h"

@implementation SMAttachmentsPanelViewController {
    SMMessageEditorController *_messageEditorController;
    SMMessage *_message;
    id __weak _toggleTarget;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	
	if(self) {
		_attachmentItems = [[NSMutableArray alloc] init];
	}
	
	return self;
}

- (void)viewDidLoad {
    SM_LOG_DEBUG(@"???");
    
    NSAssert(_collectionView, @"no collection view");
    
    _collectionView.attachmentsPanelViewController = self;

    [_collectionView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];
    
    if(_messageEditorController != nil) {
        NSAssert(_collectionView, @"no collection view");
        NSArray *supportedTypes = [NSArray arrayWithObjects:@"com.simplicity.attachment.collection.item", NSFilenamesPboardType, nil];
        
        [_collectionView registerForDraggedTypes:supportedTypes];
    }
}

- (NSUInteger)collapsedHeight {
    return _togglePanelButton.frame.size.height;
}

- (NSUInteger)uncollapsedHeight {
    return _togglePanelButton.frame.size.height + _collectionView.frame.size.height;
}

- (void)setToggleTarget:(id)toggleTarget {
    _toggleTarget = toggleTarget;
}

- (IBAction)togglePanelAction:(id)sender {
    if(_toggleTarget) {
        [_toggleTarget performSelector:@selector(toggleAttachmentsPanel:) withObject:self];
    }
    else {
        SM_LOG_WARNING(@"no toggle target");
    }
}

- (void)setMessage:(SMMessage*)message {
    NSAssert(message != nil, @"message is nil");
    NSAssert(_message == nil, @"_message already set");
    
    _message = message;

    NSAssert(_message.attachments.count > 0, @"message has no attachments, the panel should never be shown");
    
    for(NSUInteger i = 0; i < _message.attachments.count; i++) {
        SMAttachmentItem *attachmentItem = [[SMAttachmentItem alloc] initWithMCOAttachment:_message.attachments[i]];
        [_arrayController addObject:attachmentItem];
    }
    
    [_arrayController setSelectedObjects:[NSArray array]];
}

- (void)enableEditing:(SMMessageEditorController*)messageEditorController {
    NSAssert(messageEditorController, @"no messageEditorController provided");
    NSAssert(_messageEditorController == nil, @"message editor controller already set");

    _messageEditorController = messageEditorController;
}

- (BOOL)collectionView:(NSCollectionView *)collectionView canDragItemsAtIndexes:(NSIndexSet *)indexes withEvent:(NSEvent *)event {
	SM_LOG_DEBUG(@"indexes %@", indexes);

	return YES;
}

-(BOOL)collectionView:(NSCollectionView *)collectionView writeItemsAtIndexes:(NSIndexSet *)indexes toPasteboard:(NSPasteboard *)pasteboard {
	SM_LOG_DEBUG(@"indexes %@", indexes);

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

- (void)addFiles:(NSArray*)files {
    NSAssert(_messageEditorController != nil, @"no messageEditorController, editing disabled");
    
    for (NSURL *url in files) {
        SM_LOG_INFO(@"attachment: %@", [url path]);
        
        SMAttachmentItem *attachment = [[SMAttachmentItem alloc] initWithFilePath:[url path]];
        [_arrayController addObject:attachment];
        
        [_messageEditorController addAttachmentItem:attachment];
    }
}

- (void)insertFiles:(NSArray *)files atIndex:(NSInteger)index {
    [self addFiles:files];

    [_arrayController setSelectedObjects:[NSArray array]];
}

#pragma mark Attachment files manipulations

- (void)openAttachment:(SMAttachmentItem*)attachmentItem {
    NSString *filePath = [self saveAttachment:attachmentItem toPath:@"/tmp"];
    
    if(filePath == nil) {
        SM_LOG_DEBUG(@"cannot open attachment");
        return; // TODO: error popup?
    }
    
    [[NSWorkspace sharedWorkspace] openFile:filePath];
}

- (void)saveAttachment:(SMAttachmentItem*)attachmentItem {
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    
    // TODO: get the downloads folder from the user preferences
    // TODO: use the last used directory
    [savePanel setDirectoryURL:[NSURL fileURLWithPath:NSHomeDirectory()]];
    
    // TODO: use a full-sized file panel
    [savePanel beginSheetModalForWindow:[[NSApplication sharedApplication] mainWindow] completionHandler:^(NSInteger result){
        if(result == NSFileHandlingPanelOKButton) {
            [savePanel orderOut:self];
            
            NSURL *targetFileUrl = [savePanel URL];
            if(![attachmentItem writeAttachmentTo:[targetFileUrl baseURL] withFileName:[targetFileUrl relativeString]]) {
                return; // TODO: error popup
            }
            
            [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[targetFileUrl]];
        }
    }];
}

- (void)saveAttachmentToDownloads:(SMAttachmentItem*)attachmentItem {
    // TODO: get the downloads folder from the user preferences
    
    NSString *filePath = [self saveAttachment:attachmentItem toPath:NSHomeDirectory()];
    
    if(filePath == nil) {
        return; // TODO: error popup
    }
    
    NSURL *fileUrl = [NSURL fileURLWithPath:filePath];
    
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[fileUrl]];
}

- (NSString*)saveAttachment:(SMAttachmentItem*)attachmentItem toPath:(NSString*)folderPath {
    NSString *filePath = [NSString pathWithComponents:@[folderPath, attachmentItem.fileName]];
    
    if(![attachmentItem writeAttachmentTo:[NSURL fileURLWithPath:filePath]]) {
        return nil; // TODO: error popup
    }
    
    return filePath;
}

- (void)openSelectedAttachments {
    
}

- (void)saveSelectedAttachments {
    
}

- (void)saveSelectedAttachmentsToDownloads {
    
}

- (NSString*)saveSelectedAttachmentsToPath:(NSString*)folderPath {
    //TODO
    return nil;
}

#pragma mark Delegate actions

- (BOOL)collectionView:(NSCollectionView *)collectionView acceptDrop:(id<NSDraggingInfo>)draggingInfo index:(NSInteger)index dropOperation:(NSCollectionViewDropOperation)dropOperation {
    NSPasteboard *pasteboard = [draggingInfo draggingPasteboard];
    NSMutableArray *files = [NSMutableArray array];
    
    for (NSPasteboardItem *oneItem in [pasteboard pasteboardItems]) {
        NSString *urlString = [oneItem stringForType:(id)kUTTypeFileURL];
        NSURL *url = [NSURL URLWithString:urlString];
        
        if (url) {
            [files addObject:url];
        }
    }
    
    if ([files count]) {
        [self insertFiles:files atIndex:index];
    }

    return YES;
}

-(NSDragOperation)collectionView:(NSCollectionView *)collectionView validateDrop:(id<NSDraggingInfo>)draggingInfo proposedIndex:(NSInteger *)proposedDropIndex dropOperation:(NSCollectionViewDropOperation *)proposedDropOperation {
	// do not recognize any drop to itself
	// TODO: may need to add logic for messages being composed

    if (!draggingInfo.draggingSource)
    {
        SM_LOG_DEBUG(@"TODO (external)");

        // comes from external
        return NSDragOperationCopy;
    }
    
    SM_LOG_DEBUG(@"TODO (internal)");
    
    // comes from internal
    return NSDragOperationMove;
}

- (NSArray *)collectionView:(NSCollectionView *)collectionView namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropURL forDraggedItemsAtIndexes:(NSIndexSet *)indexes {
	SM_LOG_DEBUG(@"indexes %@, drop url %@", indexes, dropURL);

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
    SM_LOG_DEBUG(@"TODO");
    return [self draggingEntered:sender];
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender {
    SM_LOG_DEBUG(@"TODO");
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
