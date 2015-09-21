//
//  SMFolderDesc.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/20/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MailCore/MailCore.h>

@interface SMFolderDesc : NSObject

@property NSString *folderName;
@property char delimiter;
@property MCOIMAPFolderFlag flags;

- (id)initWithFolderName:(NSString*)folderName delimiter:(char)delimiter flags:(MCOIMAPFolderFlag)flags;

@end
