//
//  SMMailServiceProviderYandex.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/6/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMMailServiceProvider.h"

@interface SMMailServiceProviderYandex : SMMailServiceProvider

- (id)initWithEmailAddress:(NSString*)emailAddress password:(NSString*)password;

@end
