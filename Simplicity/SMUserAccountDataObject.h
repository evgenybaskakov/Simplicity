//
//  SMUserAccountDataObject.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/15/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol SMAbstractAccount;

@interface SMUserAccountDataObject : NSObject {
    @protected id<SMAbstractAccount> _account;
}

@property id<SMAbstractAccount> account;

- (id)initWithUserAccount:(id<SMAbstractAccount>)account;

@end
