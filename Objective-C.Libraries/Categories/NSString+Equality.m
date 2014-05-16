#import "NSString+Equality.h"

@implementation NSString (Equality)

- (BOOL)isEqualIgnoringCase:(NSString *)string {
    return [self caseInsensitiveCompare:string] == NSOrderedSame;
}

@end
