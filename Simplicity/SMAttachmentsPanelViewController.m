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

static NSUInteger _buttonH;

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
    else {
        SM_LOG_DEBUG(@"removing the attachments panel toggle button");

        _buttonH = _togglePanelButton.frame.size.height;

        // in the non-editing mode, we don't let the user to show/hide the attachments panel
        // it should be always shown
        [self removeToggleButton];
        
        // TODO: figure out how to disable scrolling by gestures
        _collectionView.enclosingScrollView.verticalScrollElasticity = NSScrollElasticityNone;
        _collectionView.enclosingScrollView.hasVerticalScroller = NO;
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

- (void)removeToggleButton {
    [_togglePanelButton removeFromSuperview];
    _collectionView.frame = self.view.frame;
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
    
    [self.view invalidateIntrinsicContentSize];
}

- (void)enableEditing:(SMMessageEditorController*)messageEditorController {
    NSAssert(messageEditorController, @"no messageEditorController provided");
    NSAssert(_messageEditorController == nil, @"message editor controller already set");

    _messageEditorController = messageEditorController;
    _enabledEditing = YES;
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

- (void)addMCOAttachments:(NSArray*)attachments {
    NSAssert(_messageEditorController != nil, @"no messageEditorController, editing disabled");
    
    for (MCOAttachment *mcoAttachment in attachments) {
        SM_LOG_INFO(@"attachment: %@", mcoAttachment.filename);
        
        SMAttachmentItem *attachment = [[SMAttachmentItem alloc] initWithMCOAttachment:mcoAttachment];
        [_arrayController addObject:attachment];
        
        [_messageEditorController addAttachmentItem:attachment];
        
        // NOTE: do not set the unsaved attachments flag
        //       because in this case, it is an initialization
        //       from pre-existing MCO objects
        
        // TODO: think how to fix this mess
    }
}

- (void)addFileAttachments:(NSArray*)files {
    NSAssert(_messageEditorController != nil, @"no messageEditorController, editing disabled");
    
    for (NSURL *url in files) {
        SM_LOG_INFO(@"attachment: %@", [url path]);
        
        SMAttachmentItem *attachment = [[SMAttachmentItem alloc] initWithLocalFilePath:[url path]];
        [_arrayController addObject:attachment];
        
        [_messageEditorController addAttachmentItem:attachment];

        _messageEditorController.hasUnsavedAttachments = YES;
    }
}

- (void)insertFileAttachments:(NSArray *)files atIndex:(NSInteger)index {
    [self addFileAttachments:files];

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
    [self saveAttachmentsWithDialog:@[attachmentItem]];
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

- (void)removeAttachment:(SMAttachmentItem*)attachmentItem {
    [self removeAttachments:@[attachmentItem]];
}

- (void)removeAttachments:(NSArray*)attachmentItems {
    [_arrayController removeObjects:attachmentItems];
    [_messageEditorController removeAttachmentItems:attachmentItems];
    _messageEditorController.hasUnsavedAttachments = YES;
}

- (void)openSelectedAttachments {
    NSIndexSet *selectedItemIndices = _collectionView.selectionIndexes;
    NSAssert(selectedItemIndices.count > 0, @"selectedItemIndices is 0");
    
    for(NSUInteger i = [selectedItemIndices firstIndex]; i != NSNotFound; i = [selectedItemIndices indexGreaterThanIndex:i]) {
        SMAttachmentItem *item = _attachmentItems[i];
        [self openAttachment:item];
    }
}

- (void)saveSelectedAttachments {
    NSIndexSet *selectedItemIndices = _collectionView.selectionIndexes;
    NSAssert(selectedItemIndices.count > 0, @"selectedItemIndices is 0");
              
    NSMutableArray *selectedItemsArray = [NSMutableArray arrayWithCapacity:selectedItemIndices.count];
    
    for(NSUInteger i = [selectedItemIndices firstIndex]; i != NSNotFound; i = [selectedItemIndices indexGreaterThanIndex:i]) {
        SMAttachmentItem *item = _attachmentItems[i];
        [selectedItemsArray addObject:item];
    }

    [self saveAttachmentsWithDialog:selectedItemsArray];
}

- (void)saveSelectedAttachmentsToDownloads {
    NSIndexSet *selectedItemIndices = _collectionView.selectionIndexes;
    NSAssert(selectedItemIndices.count > 0, @"selectedItemIndices is 0");
    
    for(NSUInteger i = [selectedItemIndices firstIndex]; i != NSNotFound; i = [selectedItemIndices indexGreaterThanIndex:i]) {
        SMAttachmentItem *item = _attachmentItems[i];
        [self saveAttachmentToDownloads:item];
    }
}

- (void)removeSelectedAttachments {
    NSIndexSet *selectedItemIndices = _collectionView.selectionIndexes;
    NSAssert(selectedItemIndices.count > 0, @"selectedItemIndices is 0");

    NSMutableArray *selectedItemsArray = [NSMutableArray arrayWithCapacity:selectedItemIndices.count];
    
    for(NSUInteger i = [selectedItemIndices firstIndex]; i != NSNotFound; i = [selectedItemIndices indexGreaterThanIndex:i]) {
        SMAttachmentItem *item = _attachmentItems[i];
        [selectedItemsArray addObject:item];
    }
    
    [self removeAttachments:selectedItemsArray];
}

- (void)saveAttachmentsWithDialog:(NSArray*)attachmentItems {
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    
    // TODO: get the downloads folder from the user preferences
    // TODO: use the last used directory
    [savePanel setDirectoryURL:[NSURL fileURLWithPath:NSHomeDirectory()]];
    
    // TODO: use a full-sized file panel
    [savePanel beginSheetModalForWindow:[[NSApplication sharedApplication] mainWindow] completionHandler:^(NSInteger result){
        if(result == NSFileHandlingPanelOKButton) {
            [savePanel orderOut:self];
            
            NSMutableArray *savedAttachmentUrls = [NSMutableArray arrayWithCapacity:attachmentItems.count];

            for(SMAttachmentItem *attachmentItem in attachmentItems) {
                NSURL *targetFileUrl = [savePanel URL];
                if(![attachmentItem writeAttachmentTo:[targetFileUrl baseURL] withFileName:[targetFileUrl relativeString]]) {
                    SM_LOG_ERROR(@"Could not save attachment to '%@'", targetFileUrl.baseURL);
                    return; // TODO: error popup
                }
                
                [savedAttachmentUrls addObject:targetFileUrl];
            }
            
            [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:savedAttachmentUrls];
        }
    }];
}

#pragma mark Delegate actions

- (BOOL)collectionView:(NSCollectionView *)collectionView acceptDrop:(id<NSDraggingInfo>)draggingInfo index:(NSInteger)index dropOperation:(NSCollectionViewDropOperation)dropOperation {
    NSPasteboard *pasteboard = [draggingInfo draggingPasteboard];
    NSMutableArray *files = [NSMutableArray array];
    
    for(NSPasteboardItem *oneItem in [pasteboard pasteboardItems]) {
        NSString *urlString = [oneItem stringForType:(id)kUTTypeFileURL];
        NSURL *url = [NSURL URLWithString:urlString];
        
        if(url) {
            [files addObject:url];
        }
    }
    
    if([files count]) {
        [self insertFileAttachments:files atIndex:index];
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

#pragma mark Intrinsic content size

- (void)invalidateIntrinsicContentViewSize {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SMAttachmentsPanelViewHeightChanged" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:self, @"Object", nil]];
}

- (NSSize)intrinsicContentViewSize {
    NSSize intrinsicSize = [_collectionView intrinsicContentSize];
    intrinsicSize.height += _buttonH*2;

    return intrinsicSize;
}

@end
