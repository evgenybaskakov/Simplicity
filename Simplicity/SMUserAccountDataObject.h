//
//  SMUserAccountDataObject.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/15/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SMUserAccount;

@interface SMUserAccountDataObject : NSObject {
    @protected SMUserAccount *_account;
}

- (id)initWithUserAccount:(SMUserAccount*)account;

@end
