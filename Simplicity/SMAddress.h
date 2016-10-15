//
//  SMAddress.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/22/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, SMAddressMenuRepresentation) {
    SMAddressRepresentation_FirstNameFirst,
    SMAddressRepresentation_LastNameFirst,
    SMAddressRepresentation_EmailOnly,
};

@class MCOAddress;

@interface SMAddress : NSObject

@property (readonly) NSString *firstName;
@property (readonly) NSString *lastName;
@property (readonly) NSString *email;
@property (readonly) NSString *detailedRepresentation;

+ (NSArray<SMAddress*>*)mcoAddressesToAddressList:(NSArray<MCOAddress*>*)mcoAddresses;
+ (NSArray<MCOAddress*>*)addressListToMCOAddresses:(NSArray<SMAddress*>*)mcoAddresses;
+ (NSString*)displayAddress:(NSString*)address;
+ (NSString*)extractEmailFromAddressString:(NSString*)address name:(NSString**)name;

- (id)initWithFirstName:(NSString*)firstName lastName:(NSString*)lastName email:(NSString*)email representationMode:(SMAddressMenuRepresentation)representationMode;
- (id)initWithFullName:(NSString*)fullName email:(NSString*)email representationMode:(SMAddressMenuRepresentation)representationMode;
- (id)initWithStringRepresentation:(NSString*)string;
- (id)initWithMCOAddress:(MCOAddress*)mcoAddress;

- (NSString*)stringRepresentationForMenu;
- (NSString*)stringRepresentationShort;

- (MCOAddress*)mcoAddress;

- (BOOL)matchEmail:(SMAddress*)address;

@end
