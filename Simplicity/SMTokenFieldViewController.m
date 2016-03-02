//
//  SMViewController.m
//  CustomTokenField
//
//  Created by Evgeny Baskakov on 2/11/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMTokenFieldViewController.h"
#import "SMTokenFieldView.h"
#import "SMTokenEditView.h"
#import "SMTokenView.h"

@implementation SMTokenFieldViewController {
    __weak IBOutlet NSButton *_clearButton;

    SMTokenFieldView *_tokenFieldView;
    NSMutableArray<SMTokenView*> *_tokens;
    NSMutableIndexSet *_selectedTokens;
    NSInteger _currentToken;
    SMTokenEditView *_mainTokenEditor;
    SMTokenEditView *_existingTokenEditor;
    BOOL _extendingSelectionFromText;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
    _tokens = [NSMutableArray array];
    _selectedTokens = [NSMutableIndexSet indexSet];
    _currentToken = -1;

    NSRect documentViewFrame = _scrollView.frame;
    documentViewFrame.size.width = 0;
    
    _tokenFieldView = [[SMTokenFieldView alloc] initWithFrame:documentViewFrame];
    
    [_scrollView setDocumentView:_tokenFieldView];
    
    _mainTokenEditor = [SMTokenEditView createEditToken:self];
    [_tokenFieldView addSubview:_mainTokenEditor];
    
    [self adjustTokenFrames];
    
    _clearButton.hidden = YES;
}

- (IBAction)clearButtonAction:(id)sender {
    if(_target && _clearAction) {
        [_target performSelector:_clearAction withObject:self afterDelay:0];
    }
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
    
    // Update the view, if already loaded.
}

- (void)addToken:(NSString*)tokenName contentsText:(NSString*)contentsText representedObject:(NSObject*)representedObject target:(id)target action:(SEL)action  editedAction:(SEL)editedAction deletedAction:(SEL)deletedAction {
    SMTokenView *token = [SMTokenView createToken:tokenName contentsText:contentsText representedObject:representedObject target:target action:action editedAction:editedAction deletedAction:deletedAction viewController:self];
    
    [_tokens addObject:token];
    [_tokenFieldView addSubview:token];
    
    [self adjustTokenFrames];
}

- (SMTokenView*)changeToken:(SMTokenView*)tokenView tokenName:(NSString*)tokenName contentsText:(NSString*)contentsText representedObject:(NSObject*)representedObject target:(id)target action:(SEL)action editedAction:(SEL)editedAction deletedAction:(SEL)deletedAction {

    NSUInteger idx = [_tokens indexOfObject:tokenView];
    NSAssert(idx != NSNotFound, @"token '%@' not found", tokenView.tokenName);
    
    [_tokens[idx] removeFromSuperview];

    SMTokenView *newTokenView = [SMTokenView createToken:tokenName contentsText:contentsText representedObject:representedObject target:target action:action editedAction:editedAction deletedAction:(SEL)deletedAction viewController:self];

    _tokens[idx] = newTokenView;
    
    [_tokenFieldView addSubview:newTokenView];
    
    if(tokenView.selected) {
        newTokenView.selected = YES;
    }
    
    [self adjustTokenFrames];
    
    _clearButton.hidden = NO;
    
    return newTokenView;
}

- (void)deleteToken:(SMTokenView*)tokenView {
    NSUInteger idx = [_tokens indexOfObject:tokenView];
    NSAssert(idx != NSNotFound, @"token '%@' not found", tokenView.tokenName);

    [_tokens[idx] removeFromSuperview];
    [_tokens removeObjectAtIndex:idx];
    [_selectedTokens removeIndex:idx];
    
    if(_currentToken == idx) {
        _currentToken = -1;
    }
    else if(_currentToken > idx) {
        _currentToken--;
    }
    
    for(NSUInteger i = [_selectedTokens indexGreaterThanIndex:idx]; i != NSNotFound; i = [_selectedTokens indexGreaterThanIndex:i]) {
        [_selectedTokens addIndex:i-1];
        [_selectedTokens removeIndex:i];
    }
    
    [self adjustTokenFrames];
    
    // TODO: scroll to the next visible token / text field

    [tokenView triggerDeletedAction];
    
    if(_tokens.count == 0 && _mainTokenEditor.string.length == 0) {
        _clearButton.hidden = YES;
    }
}

- (NSArray*)representedTokenObjects {
    NSMutableArray *objs = [NSMutableArray array];
    
    for(SMTokenView *token in _tokens) {
        [objs addObject:token.representedObject];
    }
    
    return objs;
}

- (NSUInteger)tokenCount {
    return _tokens.count;
}

- (NSString*)stringValue {
    return _mainTokenEditor.string;
}

- (void)editToken:(SMTokenView*)token {
    NSUInteger idx = [_tokens indexOfObject:token];
    NSAssert(idx != NSNotFound, @"token %@ not found", token.tokenName);
    
    [token removeFromSuperview];
    [_selectedTokens removeIndex:idx];
    if(_currentToken == idx) {
        _currentToken = -1;
    }
    
    NSAssert(_existingTokenEditor == nil, @"_existingTokenEditor == nil");
    
    _existingTokenEditor = [SMTokenEditView createEditToken:self];
    [_existingTokenEditor setString:token.contentsText];

    [_tokenFieldView addSubview:_existingTokenEditor];
    [_tokenFieldView.window makeFirstResponder:_existingTokenEditor];
    
    _existingTokenEditor.parentToken = token;
    token.editorView = _existingTokenEditor;
    
    [self adjustTokenFrames];
}

- (void)finishTokenEditing {
    [self stopTokenEditing:YES];
}

- (void)cancelTokenEditing {
    [self stopTokenEditing:NO];
}

- (void)stopTokenEditing:(BOOL)saveChanges {
    NSAssert(_existingTokenEditor != nil, @"_existingTokenEditor == nil");
    
    SMTokenView *token = _existingTokenEditor.parentToken;
    NSAssert(token != nil, @"parent token is nil");
    
    NSUInteger idx = [_tokens indexOfObject:token];
    NSAssert(idx != NSNotFound, @"edited token not found");
    
    [_existingTokenEditor removeFromSuperview];
    
    if(saveChanges) {
        NSString *newTokenString = _existingTokenEditor.string;
        
        if(newTokenString.length != 0) {
            if(![newTokenString isEqualToString:token.contentsText]) {
                token = [self changeToken:token tokenName:token.tokenName contentsText:newTokenString representedObject:token.representedObject target:token.target action:token.action editedAction:token.editedAction deletedAction:token.deletedAction];
                
                [token triggerEditedAction];
            }
            else {
                [_tokenFieldView addSubview:token];
                token.editorView = nil;
            }

            // Make sure the token that's been edited is not selected.
            _tokens[idx].selected = NO;
            [_selectedTokens removeIndex:idx];
        }
        else {
            // This also triggers the delete action.
            [self deleteToken:token];
            
            token = nil;
        }
    }
    else {
        [_tokenFieldView addSubview:token];
        token.editorView = nil;
    
        // Make sure the token that's been edited is not selected.
        _tokens[idx].selected = NO;
        [_selectedTokens removeIndex:idx];
    }

    _existingTokenEditor = nil;

    [_tokenFieldView.window makeFirstResponder:_tokenFieldView];

    // Redraw everything.
    [self adjustTokenFrames];
}

- (BOOL)tokenSelectionActive {
    return _selectedTokens.count > 0;
}

- (void)textViewDidChangeSelection:(NSNotification *)notification {
    //    NSLog(@"%s: %@", __FUNCTION__, notification.userInfo);
}

- (void)textDidEndEditing:(NSNotification *)notification {
    //    NSLog(@"%s: %@", __FUNCTION__, notification.userInfo);
}

- (void)textDidBeginEditing:(NSNotification *)notification {
    //    NSLog(@"%s: %@", __FUNCTION__, notification.userInfo);
}

- (void)textDidChange:(NSNotification *)notification {
    if(notification.object == _mainTokenEditor) {
        [self deleteSelectedTokens];
        [self triggerTargetAction];

        if(_tokens.count == 0 && _mainTokenEditor.string.length == 0) {
            _clearButton.hidden = YES;
        }
        else {
            _clearButton.hidden = NO;
        }
    }
    else {
        // The notified editor is a token being edited.
        // So trigger no action, just update the environment.
        [self adjustTokenFrames];
    }
}

- (void)triggerTargetAction {
    [NSObject cancelPreviousPerformRequestsWithTarget:_target selector:_action object:self];

    if(_target && _action) {
        [_target performSelector:_action withObject:self afterDelay:_actionDelay];
    }
}

- (void)triggerCancel:(SMTokenEditView*)sender {
    if(_existingTokenEditor != nil && sender == _existingTokenEditor) {
        NSUInteger tokenCount = _tokens.count;
        SMTokenView *token = _existingTokenEditor.parentToken;
        NSUInteger idx = [_tokens indexOfObject:token];
        NSAssert(idx != NSNotFound, @"edited token not found");
        
        [self cancelTokenEditing];

        if(_tokens.count == tokenCount) {
            [_selectedTokens removeAllIndexes];
            
            [self selectToken:idx];
        }
    }
    else {
        if(_target && _cancelAction) {
            [_target performSelector:_cancelAction withObject:self afterDelay:0];
        }
    }
}

- (void)triggerEnter:(SMTokenEditView*)sender {
    if(_existingTokenEditor != nil && sender == _existingTokenEditor) {
        [self finishTokenEditing];
    }
    else {
        if(_target && _enterAction) {
            [_target performSelector:_enterAction withObject:self afterDelay:0];
        }
    }
}

- (void)triggerArrowUp:(SMTokenEditView*)sender {
    if(_target && _arrowUpAction) {
        [_target performSelector:_arrowUpAction withObject:self afterDelay:0];
    }
}

- (void)triggerArrowDown:(SMTokenEditView*)sender {
    if(_target && _arrowDownAction) {
        [_target performSelector:_arrowDownAction withObject:self afterDelay:0];
    }
}

- (void)cursorLeftFrom:(SMTokenEditView*)sender jumpToBeginning:(BOOL)jumpToBeginning extendSelection:(BOOL)extendSelection {
    NSAssert(sender == _mainTokenEditor || (_existingTokenEditor != nil && sender == _existingTokenEditor), @"unknown sender");
    
    if(sender == _mainTokenEditor) {
        [_tokenFieldView.window makeFirstResponder:_tokenFieldView];

        if(_tokens.count > 0) {
            if(jumpToBeginning) {
                if(!extendSelection) {
                    [self clearCursorSelection];
                    [self selectToken:0];
                }
                else {
                    for(NSInteger i = 0; i < _tokens.count; i++) {
                        [_selectedTokens addIndex:i];

                        _tokens[i].selected = YES;
                    }
                    
                    _currentToken = 0;

                    NSRange range = _mainTokenEditor.selectedRange;
                    [_mainTokenEditor setSelectedRange:NSMakeRange(0, range.location + range.length)];
                    [_tokenFieldView scrollRectToVisible:_tokens[_currentToken].frame];
                }
            }
            else if(!extendSelection && _selectedTokens.count > 1) {
                NSInteger firstToken = _selectedTokens.firstIndex;
                
                [self clearCursorSelection];
                [self selectToken:firstToken];
            }
            else {
                [self clearCursorSelection];
                [self selectToken:_tokens.count-1];
            }

            if(!extendSelection) {
                [_mainTokenEditor setSelectedRange:NSMakeRange(0, 0)];
            }

            _extendingSelectionFromText = extendSelection;
        }
        else {
            [_tokenFieldView.window makeFirstResponder:_mainTokenEditor];
            [_mainTokenEditor setSelectedRange:NSMakeRange(0, 0)];
        }
    }
    else {
        NSUInteger tokenIdx = [_tokens indexOfObject:sender.parentToken];
        NSAssert(tokenIdx != NSNotFound, @"edited token not found");
        
        if(tokenIdx > 0) {
            [self clearCursorSelection];

            if(jumpToBeginning) {
                if(!extendSelection) {
                    [self selectToken:0];
                }
                else {
                    for(NSInteger i = 0; i < tokenIdx; i++) {
                        [_selectedTokens addIndex:i];
                        _tokens[i].selected = YES;
                    }
                    
                    _currentToken = 0;

                    [_tokenFieldView scrollRectToVisible:_tokens[_currentToken].frame];
                }
            }
            else {
                [self selectToken:tokenIdx - 1];
            }
            
            [self finishTokenEditing];
        }
    }
}

- (void)cursorRightFrom:(SMTokenEditView*)sender jumpToEnd:(BOOL)jumpToEnd extendSelection:(BOOL)extendSelection {
    NSAssert(sender == _mainTokenEditor || sender == _existingTokenEditor, @"unknown sender");
    
    if(sender == _mainTokenEditor) {
        // Nothing to do.
    }
    else {
        NSUInteger tokenIdx = [_tokens indexOfObject:sender.parentToken];
        NSAssert(tokenIdx != NSNotFound, @"edited token not found");
        
        [self clearCursorSelection];

        BOOL itWasLastToken = NO;
        if(tokenIdx + 1 < _tokens.count) {
            [self selectToken:tokenIdx + 1];
        }
        else {
            itWasLastToken = YES;
        }
        
        [self finishTokenEditing];
        
        if(itWasLastToken) {
            [_tokenFieldView.window makeFirstResponder:_mainTokenEditor];
            [_mainTokenEditor setSelectedRange:NSMakeRange(0, 0)];
            
            _currentToken = -1;
        }
    }
}

- (void)selectAll:(id)sender {
    [_selectedTokens addIndexesInRange:NSMakeRange(0, _tokens.count)];

    for(SMTokenView *token in _tokens) {
        token.selected = YES;
    }

    if(_tokens.count > 0) {
        _currentToken = 0;
    }

    _extendingSelectionFromText = YES;
    [_mainTokenEditor setSelectedRange:NSMakeRange(0, _mainTokenEditor.string.length)];
}

- (void)selectToken:(NSUInteger)idx {
    _currentToken = idx;
    _tokens[_currentToken].selected = YES;
    [_selectedTokens addIndex:_currentToken];
    [_tokenFieldView scrollRectToVisible:_tokens[_currentToken].frame];
}

- (void)clearCursorSelection {
    [_selectedTokens enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        _tokens[idx].selected = NO;
    }];
    
    [_selectedTokens removeAllIndexes];

    _extendingSelectionFromText = NO;
}

- (void)keyDown:(NSEvent *)theEvent {
    const NSUInteger codeLeft = 123, codeRight = 124, codeDelete = 51, codeForwardDelete = 117;
    const NSUInteger codeEscape = 53, codeArrowDown = 125, codeArrowUp = 126, codeEnter = 36;
    
    if(theEvent.keyCode == codeLeft) { // Left
        NSUInteger flags = theEvent.modifierFlags & NSDeviceIndependentModifierFlagsMask;
        BOOL extendSelection = (flags & NSShiftKeyMask) != 0;
        BOOL selectionWasExtendingFromText = _extendingSelectionFromText;
        NSUInteger oldSelectionLen = _selectedTokens.count;
        NSInteger oldFirstToken = (oldSelectionLen > 0? _selectedTokens.firstIndex : -1);

        if(!extendSelection) {
            [self clearCursorSelection];
            
            if(_currentToken == 0) {
                _tokens[_currentToken].selected = YES;

                [_selectedTokens addIndex:_currentToken];
            }

            [_mainTokenEditor setSelectedRange:NSMakeRange(0, 0)];
        }
        else {
            if(theEvent.modifierFlags & NSCommandKeyMask) {
                while(_selectedTokens.count > 1 && _currentToken == _selectedTokens.lastIndex) {
                    _tokens[_currentToken].selected = NO;
                    [_selectedTokens removeIndex:_currentToken];

                    _currentToken--;
                }
            }
            else {
                if(_selectedTokens.count > 1 && _currentToken == _selectedTokens.lastIndex) {
                    _tokens[_currentToken].selected = NO;
                    [_selectedTokens removeIndex:_currentToken];
                }
            }
        }

        if(_currentToken > 0) {
            if(theEvent.modifierFlags & NSCommandKeyMask) {
                for(NSUInteger i = _currentToken; i > 0; i--) {
                    if(extendSelection) {
                        _tokens[i].selected = YES;
                        [_selectedTokens addIndex:i];
                    }
                    else {
                        _tokens[i].selected = NO;
                        [_selectedTokens removeIndex:i];
                    }
                }

                [self selectToken:0];
            }
            else if(!extendSelection && (oldSelectionLen > 1 || selectionWasExtendingFromText)) {
                [self selectToken:oldFirstToken];
            }
            else {
                [self selectToken:_currentToken - 1];
            }
        }
    }
    else if(theEvent.keyCode == codeRight) { // Right
        NSUInteger flags = theEvent.modifierFlags & NSDeviceIndependentModifierFlagsMask;
        BOOL extendSelection = (flags & NSShiftKeyMask) != 0;
        BOOL selectionWasExtendingFromText = _extendingSelectionFromText;
        NSUInteger oldSelectionLen = _selectedTokens.count;
        NSInteger oldLastToken = (oldSelectionLen > 0? _selectedTokens.lastIndex : -1);
        
        if(!extendSelection) {
            [self clearCursorSelection];
        }
        else {
            if(theEvent.modifierFlags & NSCommandKeyMask) {
                while(_selectedTokens.count > 1 && _currentToken == _selectedTokens.firstIndex) {
                    _tokens[_currentToken].selected = NO;
                    [_selectedTokens removeIndex:_currentToken];
                    
                    _currentToken++;
                }
            }
            else {
                if(_selectedTokens.count > 1 && _currentToken == _selectedTokens.firstIndex) {
                    _tokens[_currentToken].selected = NO;
                    [_selectedTokens removeIndex:_currentToken];
                }
            }
        }

        if(theEvent.modifierFlags & NSCommandKeyMask) {
            if(extendSelection) {
                for(NSInteger i = _currentToken; i < _tokens.count; i++) {
                    _tokens[i].selected = YES;
                    
                    [_selectedTokens addIndex:i];
                }
                
                _currentToken = _tokens.count-1;
                [_tokenFieldView scrollRectToVisible:_tokens[_currentToken].frame];

                [_tokenFieldView.window makeFirstResponder:_mainTokenEditor];

                NSRange selectedRange = NSMakeRange(0, _mainTokenEditor.string.length);

                [_mainTokenEditor setSelectedRange:selectedRange];
                [_mainTokenEditor scrollRangeToVisible:selectedRange];
            }
            else {
                [self clearCursorSelection];
                
                [_tokenFieldView.window makeFirstResponder:_mainTokenEditor];
                
                NSRange selectedRange = NSMakeRange(_mainTokenEditor.string.length, 0);
                
                [_mainTokenEditor setSelectedRange:selectedRange];
                [_mainTokenEditor scrollRangeToVisible:selectedRange];
            }
        }
        else {
            if(selectionWasExtendingFromText && !extendSelection) {
                NSRange range = _mainTokenEditor.selectedRange;

                [_tokenFieldView.window makeFirstResponder:_mainTokenEditor];
                [_mainTokenEditor setSelectedRange:NSMakeRange(range.location + range.length, 0)];
            }
            else {
                if(!extendSelection && oldSelectionLen > 1) {
                    [self selectToken:oldLastToken];
                }
                else if(_currentToken >= 0 && _currentToken < _tokens.count-1) {
                    [self selectToken:_currentToken + 1];
                }
                else if(_currentToken == _tokens.count-1) {
                    [_tokenFieldView.window makeFirstResponder:_mainTokenEditor];

                    if(!extendSelection) {
                        _currentToken = -1;
                        
                        [_mainTokenEditor setSelectedRange:NSMakeRange(0, 0)];
                    }
                    else {
                        NSRange range = _mainTokenEditor.selectedRange;
                        
                        if(range.length == 0) {
                            [_mainTokenEditor setSelectedRange:NSMakeRange(0, 1)];
                        }
                        else {
                            [_mainTokenEditor setSelectedRange:NSMakeRange(0, 0)];
                            [_mainTokenEditor setSelectedRange:range];
                        }
                    }

                    [_mainTokenEditor scrollRectToVisible:NSMakeRect(0, 0, 100, 15)]; // TODO: ???
                }
            }
        }
    }
    else if(theEvent.keyCode == codeEscape) {
        [self triggerCancel:nil];
    }
    else if(theEvent.keyCode == codeArrowUp) {
        [self triggerArrowUp:nil];
    }
    else if(theEvent.keyCode == codeArrowDown) {
        [self triggerArrowDown:nil];
    }
    else if(theEvent.keyCode == codeEnter) {
        [self triggerEnter:nil];
    }
    else {
        if(theEvent.keyCode == codeDelete || theEvent.keyCode == codeForwardDelete) {
            [self deleteSelectedTokensAndText];
            [self triggerTargetAction];
        }
        else {
            [super keyDown:theEvent];
        }
    }
}

- (void)deleteSelectedTokens {
    [self deleteTokensAndText:NO selectedTokensOnly:YES];
}

- (void)deleteSelectedTokensAndText {
    [self deleteTokensAndText:YES selectedTokensOnly:YES];
}

- (void)deleteAllTokensAndText {
    [self deleteTokensAndText:YES selectedTokensOnly:NO];
}

- (void)deleteTokensAndText:(BOOL)deleteText selectedTokensOnly:(BOOL)selectedTokensOnly {
    if(selectedTokensOnly) {
        [_selectedTokens enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
            [_tokens[idx] removeFromSuperview];
            
            if(_tokens[idx].editorView) {
                _tokens[idx].editorView = nil;

                [_existingTokenEditor removeFromSuperview];
                _existingTokenEditor = nil;
            }
        }];

        [_tokens removeObjectsAtIndexes:_selectedTokens];

        if(deleteText) {
            [_mainTokenEditor deleteToBeginningOfLine:self];
        }
    }
    else {
        for(SMTokenView *token in _tokens) {
            [token removeFromSuperview];
        }

        [_tokens removeAllObjects];

        if(deleteText) {
            [_mainTokenEditor setString:@""];
        }

        if(_existingTokenEditor) {
            [_existingTokenEditor removeFromSuperview];
            _existingTokenEditor = nil;
        }
    }
    
    [_selectedTokens removeAllIndexes];
    _currentToken = -1;
    
    [self adjustTokenFrames];
    
    [_tokenFieldView.window makeFirstResponder:_mainTokenEditor];

    if(_tokens.count == 0 && _mainTokenEditor.string.length == 0) {
        _clearButton.hidden = YES;
    }
}

- (void)adjustTokenFrames {
    for(NSUInteger i = 0; i < _tokens.count; i++) {
        SMTokenView *token = _tokens[i];
        
        CGFloat xpos;
        
        if(i == 0) {
            xpos = 0;
        }
        else {
            SMTokenView *prevToken = _tokens[i-1];
            
            if(prevToken.editorView != nil) {
                xpos = prevToken.editorView.frame.origin.x + prevToken.editorView.frame.size.width + 4;
            }
            else {
                xpos = prevToken.frame.origin.x + prevToken.frame.size.width + 4;
            }
        }
        
        if(token.editorView != nil) {
            CGFloat leftDelta = 3;
            CGFloat rightDelta = 7;
            [token.editorView setFrame:NSMakeRect(xpos - leftDelta, 1, token.editorView.attributedString.size.width + rightDelta, 15)];
        }
        else {
            [token setFrame:NSMakeRect(xpos, 2, token.frame.size.width, token.frame.size.height)];
        }
    }

    CGFloat xpos;
    
    if(_tokens.count == 0) {
        xpos = 0;
    }
    else {
        SMTokenView *prevToken = _tokens.lastObject;

        if(prevToken.editorView != nil) {
            xpos = prevToken.editorView.frame.origin.x + prevToken.editorView.frame.size.width + 1;
        }
        else {
            xpos = prevToken.frame.origin.x + prevToken.frame.size.width + 1;
        }
    }

    CGFloat delta = 10;
    if(xpos + _mainTokenEditor.attributedString.size.width + delta < _scrollView.frame.size.width) {
        _mainTokenEditor.textContainer.size = NSMakeSize(_scrollView.frame.size.width - xpos, _mainTokenEditor.textContainer.size.height);
    }
    else {
        _mainTokenEditor.textContainer.size = NSMakeSize(_mainTokenEditor.attributedString.size.width + delta, _mainTokenEditor.textContainer.size.height);
    }
    
    _mainTokenEditor.frame = NSMakeRect(xpos, 1, _mainTokenEditor.textContainer.size.width, 15);
    
    _tokenFieldView.frame = NSMakeRect(_tokenFieldView.frame.origin.x, _tokenFieldView.frame.origin.y, xpos + _mainTokenEditor.frame.size.width, _tokenFieldView.frame.size.height);
}

- (void)tokenMouseDown:(SMTokenView*)token event:(NSEvent *)theEvent {
    [self clearCursorSelection];
    
    if(_existingTokenEditor != nil) {
        [self finishTokenEditing];
    }
    
    _currentToken = [_tokens indexOfObject:token];
    
    token.selected = YES;
    
    [_selectedTokens addIndex:_currentToken];
    [_mainTokenEditor setSelectedRange:NSMakeRange(0, 0)];
    [_tokenFieldView.window makeFirstResponder:_tokenFieldView];
    [_tokenFieldView scrollRectToVisible:_tokens[_currentToken].frame];
    
    // Force display in order to redraw the view if it just becomes 
    // the first responder and may need to refresh the graphics state.
    [self.view display];
}

- (void)clickWithinTokenEditor:(SMTokenEditView*)tokenEditor {
    [self clearCursorSelection];
    
    if(tokenEditor == _mainTokenEditor && _existingTokenEditor != nil) {
        [self finishTokenEditing];
    }
}

- (NSArray<NSString *> *)textView:(NSTextView *)textView completions:(NSArray<NSString *> *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(nullable NSInteger *)index {
    *index = -1;
    return nil;
}

@end
