// ObjCExceptionCatcher.h
// Swift에서 NSException을 catch하기 위한 Objective-C 브릿지
// 사용 후 삭제 예정

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ObjCExceptionCatcher : NSObject

/// NSException을 catch하면서 블록 실행
/// @param tryBlock 실행할 블록
/// @param catchBlock 예외 발생 시 실행할 블록 (예외 메시지 전달)
/// @return tryBlock의 반환값 또는 nil
+ (nullable id)tryBlock:(id _Nullable (^)(void))tryBlock
             catchBlock:(void (^)(NSString *exceptionMessage))catchBlock;

/// 안전하게 KVC로 값 가져오기
/// @param object 대상 객체
/// @param key 키 이름
/// @return 값 또는 nil (예외 발생 시)
+ (nullable id)safeValueForKey:(NSString *)key onObject:(NSObject *)object;

@end

NS_ASSUME_NONNULL_END
