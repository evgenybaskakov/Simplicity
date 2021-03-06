//
//  SMAttachmentsPanelViewContoller.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 1/23/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMPreferencesController.h"
#import "SMMessage.h"
#import "SMBox2.h"
#import "SMFileUtils.h"
#import "SMAttachmentItem.h"
#import "SMMessageEditorController.h"
#import "SMAttachmentsPanelView.h"
#import "SMAttachmentsPanelViewItem.h"
#import "SMAttachmentsPanelViewController.h"

static NSUInteger _buttonH;

@implementation SMAttachmentsPanelViewController {
    SMMessageEditorController *_messageEditorController;
    SMMessage *_message;
    id __weak _toggleTarget;
    SEL _toggleAction;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if(self) {
        _attachmentItems = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (void)viewDidLoad {
    _collectionView.attachmentsPanelViewController = self;

    [_collectionView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];
    
    if(_messageEditorController != nil) {
        NSAssert(_collectionView, @"no collection view");
        NSArray *supportedTypes = [NSArray arrayWithObjects:@"com.simplicity.attachment.collection.item", NSFilenamesPboardType, nil];
        
        [_collectionView registerForDraggedTypes:supportedTypes];

        [_outerBox removeFromSuperview];
    }
    else {
        _buttonH = _togglePanelButton.frame.size.height;

        // in the non-editing mode, we don't let the user to show/hide the attachments panel
        // it should be always shown
        [self removeToggleButton];
        
        _collectionView.enclosingScrollView.hasVerticalScroller = NO;
        _collectionView.enclosingScrollView.hasHorizontalScroller = NO;

        _outerBox.transparent = YES;
        _outerBox.frame = self.view.frame;
    }
}

- (NSUInteger)collapsedHeight {
    return _togglePanelButton.frame.size.height;
}

- (NSUInteger)uncollapsedHeight {
    return _togglePanelButton.frame.size.height + _collectionView.frame.size.height;
}

- (void)setToggleTarget:(id)toggleTarget action:(SEL)toggleAction {
    _toggleTarget = toggleTarget;
    _toggleAction = toggleAction;
}

- (void)removeToggleButton {
    [_togglePanelButton removeFromSuperview];
    _collectionView.frame = self.view.frame;
}

- (IBAction)togglePanelAction:(id)sender {
    if(_toggleTarget) {
        [_toggleTarget performSelector:_toggleAction withObject:self afterDelay:0];
    }
    else {
        SM_LOG_WARNING(@"no toggle target");
    }
}

static NSSize scalePreviewImage(NSSize imageSize) {
    const NSSize targetSize = NSMakeSize(115, 87);
    
    if(!NSEqualSizes(imageSize, targetSize)) {
        CGFloat width = imageSize.width;
        CGFloat height = imageSize.height;
        
        CGFloat scaleFactor = MAX(targetSize.width / width, targetSize.height / height);
        
        CGFloat scaledWidth = width * scaleFactor;
        CGFloat scaledHeight = height * scaleFactor;
        
        return NSMakeSize(scaledWidth, scaledHeight);
    }
    else {
        return targetSize;
    }
}

- (NSImage*)standardAttachmentIcon:(NSString*)attachmentFilename index:(NSUInteger)index {
    NSString *attachmentFilenameLowercase = [attachmentFilename lowercaseString];
    NSString *fileExtension = [attachmentFilenameLowercase pathExtension];
    
    NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFileType:fileExtension];

    return icon;
}

- (void)loadMCOAttachmentPreview:(MCOAttachment*)mcoAttachment attachmentItem:(SMAttachmentItem*)attachmentItem {
    NSString *attachmentFilename = mcoAttachment.filename;

    if([SMFileUtils imageFileType:attachmentFilename]) {
        SMAttachmentsPanelViewController __weak *weakSelf = self;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            SMAttachmentsPanelViewController *_self = weakSelf;
            if(!_self) {
                SM_LOG_WARNING(@"object is gone");
                return;
            }
            
            NSData *attachmentData = mcoAttachment.data;
            NSImage *image = [[NSImage alloc] initWithData:attachmentData];
            
            if(![_self setPreviewImageAsync:image attachmentItem:attachmentItem]) {
                SM_LOG_DEBUG(@"Could not load attachment image '%@'", attachmentFilename);
            }
        });
    }
}

- (void)loadFileAttachmentPreview:(NSURL*)fileUrl attachmentItem:(SMAttachmentItem*)attachmentItem {
    NSString *attachmentFilename = fileUrl.path;
    
    if([SMFileUtils imageFileType:attachmentFilename]) {
        SMAttachmentsPanelViewController __weak *weakSelf = self;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            SMAttachmentsPanelViewController *_self = weakSelf;
            if(!_self) {
                SM_LOG_WARNING(@"object is gone");
                return;
            }
            
            NSImage *image = [[NSImage alloc] initWithContentsOfURL:fileUrl];
            
            if(![_self setPreviewImageAsync:image attachmentItem:attachmentItem]) {
                SM_LOG_DEBUG(@"Could not load attachment image '%@'", attachmentFilename);
            }
        });
    }
}

- (BOOL)setPreviewImageAsync:(NSImage*)image attachmentItem:(SMAttachmentItem*)attachmentItem {
    if(image != nil && [image isValid]) {
        [image setSize:scalePreviewImage(image.size)];
        
        // Use the TIFFRepresentation method to pre-load the image data.
        // Othwerwise, there will be a noticeable lag in the main event processing,
        // because NSImage:initWithData method does not actually parse the provided data.
        [image TIFFRepresentation];

        SMAttachmentsPanelViewController __weak *weakSelf = self;

        dispatch_async(dispatch_get_main_queue(), ^{
            SMAttachmentsPanelViewController *_self = weakSelf;
            if(!_self) {
                SM_LOG_WARNING(@"object is gone");
                return;
            }
            
            // Find the originally requested item.
            // Note that as this is an asynchronous call, so the panel contents might be
            // reordered and hence an index lookup woudn't be accurate.
            for(NSUInteger i = 0; i < _self->_collectionView.content.count; i++) {
                if(_self->_collectionView.content[i] == attachmentItem) {
                    SMAttachmentsPanelViewItem *item = (SMAttachmentsPanelViewItem*)[_self->_collectionView itemAtIndex:i];
                    
                    [item setPreviewImage:image];
                    break;
                }
            }
        });
        
        return TRUE;
    }
    else {
        return FALSE;
    }
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

- (void)initAttachmentItem:(SMAttachmentItem*)attachmentItem {
    [_arrayController addObject:attachmentItem];
    
    NSUInteger attachmentIndex = [(NSArray*)[_arrayController arrangedObjects] count] - 1;
    NSImage *icon = [self standardAttachmentIcon:attachmentItem.fileName index:attachmentIndex];
    SMAttachmentsPanelViewItem *item = (SMAttachmentsPanelViewItem*)[_collectionView itemAtIndex:attachmentIndex];
    
    [icon setSize:scalePreviewImage(item.imageView.bounds.size)];
    
    item.imageView.image = icon;
}

- (void)setMessage:(SMMessage*)message {
    NSAssert(message != nil, @"message is nil");
    NSAssert(_message == nil, @"_message already set");
    
    _message = message;
    
    NSAssert(_message.attachments.count > 0, @"message has no attachments, the panel should never be shown");
    
    for(MCOAttachment *mcoAttachment in _message.attachments) {
        SMAttachmentItem *attachmentItem = [[SMAttachmentItem alloc] initWithMCOAttachment:mcoAttachment];

        [self initAttachmentItem:attachmentItem];
        [self loadMCOAttachmentPreview:mcoAttachment attachmentItem:attachmentItem];
    }
    
    [_arrayController setSelectedObjects:[NSArray array]];
    
    [self performSelector:@selector(invalidateIntrinsicContentViewSize) withObject:nil afterDelay:0];
}

- (void)setMCOAttachments:(NSArray*)attachments {
    NSAssert(_messageEditorController != nil, @"no messageEditorController, editing disabled");
    
    for (MCOAttachment *mcoAttachment in attachments) {
        SMAttachmentItem *attachmentItem = [[SMAttachmentItem alloc] initWithMCOAttachment:mcoAttachment];
        
        [self initAttachmentItem:attachmentItem];
        [self loadMCOAttachmentPreview:mcoAttachment attachmentItem:attachmentItem];
        
        [_messageEditorController addAttachmentItem:attachmentItem];
    }

    // Do not set the unsaved attachments flag because in this case,
    // it is an initialization from pre-existing MCO objects
}

- (void)addFileAttachments:(NSArray*)files {
    NSAssert(_messageEditorController != nil, @"no messageEditorController, editing disabled");
    
    for (NSURL *url in files) {
        SMAttachmentItem *attachmentItem = [[SMAttachmentItem alloc] initWithLocalFilePath:[url path]];
        
        [self initAttachmentItem:attachmentItem];
        [self loadFileAttachmentPreview:url attachmentItem:attachmentItem];

        [_messageEditorController addAttachmentItem:attachmentItem];
    }
    
    if(files.count != 0) {
        _messageEditorController.hasUnsavedAttachments = YES;
    }
}

- (void)insertFileAttachments:(NSArray *)files atIndex:(NSInteger)index {
    [self addFileAttachments:files];

    [_arrayController setSelectedObjects:[NSArray array]];
}

#pragma mark Attachment files manipulations

- (void)openAttachment:(SMAttachmentItem*)attachmentItem {
    NSString *tempDir = [[SMAppDelegate systemTempDir] path];
    NSString *filePath = [self saveAttachment:attachmentItem toPath:tempDir];
    
    if(filePath == nil) {
        SM_LOG_WARNING(@"cannot open attachment");
        return; // TODO: error popup?
    }
    
    [[NSWorkspace sharedWorkspace] openFile:filePath];
}

- (void)saveAttachment:(SMAttachmentItem*)attachmentItem {
    [self saveAttachmentsWithDialog:@[attachmentItem]];
}

- (void)saveAttachmentToDownloads:(SMAttachmentItem*)attachmentItem {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    NSString *downloadsFolder = [[appDelegate preferencesController] downloadsFolder];
    NSAssert(downloadsFolder != nil, @"downloadsFolder is nil");
    
    NSString *filePath = [self saveAttachment:attachmentItem toPath:downloadsFolder];
    
    if(filePath == nil) {
        NSAlert *alert = [[NSAlert alloc] init];
        
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:[NSString stringWithFormat:@"Could not save attachment to %@", downloadsFolder]];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert runModal];

        return;
    }
    
    NSURL *fileUrl = [NSURL fileURLWithPath:filePath];
    
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[fileUrl]];
}

- (NSString*)saveAttachment:(SMAttachmentItem*)attachmentItem toPath:(NSString*)folderPath {
    NSString *fileName = attachmentItem.fileName;
    
    if(![attachmentItem writeAttachmentTo:[NSURL fileURLWithPath:folderPath] withFileName:fileName]) {
        return nil; // TODO: error popup
    }
    
    NSString *filePath = [NSString pathWithComponents:@[folderPath, fileName]];
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

- (void)saveAllAttachments {
    NSMutableArray *itemsArray = [NSMutableArray arrayWithCapacity:_attachmentItems.count];

    for(SMAttachmentItem *item in _attachmentItems) {
        [itemsArray addObject:item];
    }

    [self saveAttachmentsWithDialog:itemsArray];
}

- (void)saveAllAttachmentsToDownloads {
    for(SMAttachmentItem *item in _attachmentItems) {
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
    NSOpenPanel *openDlg = [NSOpenPanel openPanel];
    
    [openDlg setCanChooseFiles:NO];
    [openDlg setAllowsMultipleSelection:NO];
    [openDlg setCanChooseDirectories:YES];
    
    [openDlg setPrompt:@"Save attachments"];
    
    if([openDlg runModal] == NSModalResponseOK) {
        NSURL *targetDirUrl = [[openDlg URLs] firstObject];
        
        NSMutableArray *savedAttachmentUrls = [NSMutableArray arrayWithCapacity:attachmentItems.count];
        
        for(SMAttachmentItem *attachmentItem in attachmentItems) {
            if(![attachmentItem writeAttachmentTo:targetDirUrl withFileName:attachmentItem.fileName]) {
                SM_LOG_ERROR(@"Could not save attachment '%@' to '%@'", attachmentItem.fileName, targetDirUrl);
                return; // TODO: error popup
            }
            
            [savedAttachmentUrls addObject:[NSURL URLWithString:attachmentItem.fileName relativeToURL:targetDirUrl]];
        }
        
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:savedAttachmentUrls];
    }
}

- (void)unselectAllAttachments {
    [_collectionView deselectAll:self];
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

#pragma mark Key handling

- (void)keyDown:(NSEvent *)theEvent {
    if(theEvent.type == NSKeyDown && (theEvent.modifierFlags & NSDeviceIndependentModifierFlagsMask) == 0) {
        NSString *pressedChars = [theEvent characters];
        
        if([pressedChars length] == 1) {
            unichar pressedUnichar = [pressedChars characterAtIndex:0];

            if(_enabledEditing) {
                if((pressedUnichar == NSDeleteCharacter) || (pressedUnichar == NSDeleteFunctionKey)) {
                    SM_LOG_DEBUG(@"delete key pressed");
                    
                    [self removeSelectedAttachments];
                }
            }
        }
    }
}

@end
