//
//  SMAddressListElement.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/22/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SMAddressListElement : NSObject

@property (readonly) NSString *firstName;
@property (readonly) NSString *lastName;
@property (readonly) NSString *email;

- (id)initWithFirstName:(NSString*)firstName lastName:(NSString*)lastName email:(NSString*)email;
- (id)initWithStringRepresentation:(NSString*)string;

- (NSString*)stringRepresentation;
- (NSString*)stringRepresentationShort;

@end