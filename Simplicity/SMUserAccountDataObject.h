//
//  SMUserAccountDataObject.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/15/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SMAbstractAccount.h"

@interface SMUserAccountDataObject : NSObject {
    @protected NSObject<SMAbstractAccount> *_account;
}

- (id)initWithUserAccount:(NSObject<SMAbstractAccount>*)account;

@end
