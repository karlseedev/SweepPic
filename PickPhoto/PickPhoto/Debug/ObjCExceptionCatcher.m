// ObjCExceptionCatcher.m
// Swift에서 NSException을 catch하기 위한 Objective-C 브릿지
// 사용 후 삭제 예정

#import "ObjCExceptionCatcher.h"

@implementation ObjCExceptionCatcher

+ (nullable id)tryBlock:(id _Nullable (^)(void))tryBlock
             catchBlock:(void (^)(NSString *exceptionMessage))catchBlock {
    @try {
        return tryBlock();
    }
    @catch (NSException *exception) {
        if (catchBlock) {
            catchBlock(exception.reason ?: exception.name);
        }
        return nil;
    }
}

+ (nullable id)safeValueForKey:(NSString *)key onObject:(NSObject *)object {
    @try {
        return [object valueForKey:key];
    }
    @catch (NSException *exception) {
        // 예외 발생 시 nil 반환 (로그 없이 조용히)
        return nil;
    }
}

@end
