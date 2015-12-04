//
//  MKColorWell+Bindings.m
//  MKPopoverColorWell
//
//  via http://www.tomdalling.com/blog/cocoa/implementing-your-own-cocoa-bindings
//

#import "SMLog.h"
#import "MKColorWell+Bindings.h"

@implementation MKColorWell (Bindings)
-(void)propagateValue:(id)value
           forBinding:(NSString*)binding;
{
    NSParameterAssert(binding != nil);
    
    // WARNING: bindingInfo contains NSNull, so it must be accounted for
    NSDictionary* bindingInfo = [self infoForBinding:binding];
    if (!bindingInfo)
        return; // there is no binding
    
    // apply the value transformer, if one has been set
    NSDictionary* bindingOptions = [bindingInfo objectForKey:NSOptionsKey];
    if (bindingOptions) {
        NSValueTransformer* transformer = [bindingOptions valueForKey:NSValueTransformerBindingOption];
        if (!transformer || (id)transformer == [NSNull null]) {
            NSString* transformerName = [bindingOptions valueForKey:NSValueTransformerNameBindingOption];
            if(transformerName && (id)transformerName != [NSNull null]){
                transformer = [NSValueTransformer valueTransformerForName:transformerName];
            }
        }
        
        if (transformer && (id)transformer != [NSNull null]) {
            if ([[transformer class] allowsReverseTransformation]) {
                value = [transformer reverseTransformedValue:value];
            } else {
                SM_LOG_DEBUG(@"WARNING: binding \"%@\" has value transformer, but it doesn't allow reverse transformations", binding);
            }
        }
    }
    
    id boundObject = [bindingInfo objectForKey:NSObservedObjectKey];
    if (!boundObject || boundObject == [NSNull null]) {
        SM_LOG_DEBUG(@"ERROR: NSObservedObjectKey was nil for binding \"%@\" in %s", binding, __PRETTY_FUNCTION__);
        return;
    }
    
    NSString* boundKeyPath = [bindingInfo objectForKey:NSObservedKeyPathKey];
    if (!boundKeyPath || (id)boundKeyPath == [NSNull null]) {
        SM_LOG_DEBUG(@"ERROR: NSObservedKeyPathKey was nil for binding \"%@\" in %s", binding, __PRETTY_FUNCTION__);
        return;
    }

    id boundValue = [boundObject valueForKeyPath:boundKeyPath];
    if ([boundValue isNotEqualTo:value] || (nil == boundValue && value))
        [boundObject setValue:value forKeyPath:boundKeyPath];
}
@end
