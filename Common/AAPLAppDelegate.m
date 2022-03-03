/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Implementation of the iOS app delegate.
*/

#import "AAPLAppDelegate.h"
#import <objc/runtime.h>

struct Tesss {
    double base;
    double aaa;
    int aaa3;
    bool aaa2;
    double aaa31;
    bool aaa22;
    double aaa32;
    int aak;
    bool aaa23;
};

@interface Testttt: NSObject
@property (nonatomic, assign) double aaa;   //8
@property (nonatomic, assign) int aaa3;    //4
@property (nonatomic, assign) bool aaa2;    //1
@property (nonatomic, assign) double aaa31;   //8
@property (nonatomic, assign) bool aaa22;    //1

@property (nonatomic, assign) double aaa32;   //8
@property (nonatomic, assign) int aak;    //42
@property (nonatomic, assign) bool aaa23;    //1

+ (void)test;
@end

@implementation Testttt

+ (void)test {
    NSLog(@"aaa");
}
@end

@interface KKKKK : Testttt
{
//    NSNumber* _kkk  __attr;
}

@property (nonatomic, strong, direct) NSNumber* kkk;
//- (void)y __attribute__((objc_direct));
@end

@implementation KKKKK

- (void)setKkk:(NSNumber *)kkk {
    _kkk = kkk;
}

@end

@implementation AAPLAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
//    int arrayName[4] = {10, 20, 30, 40};
//    int *p = (int *)(&arrayName + 1);
//    NSLog(@"===================\n\n\n%d\n\n\n=========", *(p - 1));
//
//    dispatch_queue_t q = dispatch_queue_create("aaaaa.aaalll", DISPATCH_QUEUE_CONCURRENT);
//    for(int i = 0; i < 9999; i++) {
//        dispatch_async(q, ^{
//            usleep(30000);
//            NSLog(@"aaa %d", i);
//        });
//    }
//
//    dispatch_barrier_sync(q, ^{
//        NSLog(@"aaa");
//    });

    KKKKK* lk = [KKKKK new];
//    [lk setValue:@(3) forKey:@"kkk"];
    [lk addObserver:self forKeyPath:@"kkk" options:NSKeyValueObservingOptionNew context:nil];
//    [lk performSelector:@selector(setKkk:) withObject:@3];
//    [lk test];
//    size_t lll = malloc_size((__bridge const void *)(self));
    [lk setKkk:@4];
    NSLog(@"Tesss: %ld  %ld", sizeof(struct Tesss), class_getInstanceSize([Testttt class]));
    // 主队列

//    dispatch_queue_t mainQueue = dispatch_get_main_queue();
//
//    // 全局队列
//
//    dispatch_queue_t globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
//#if 0
//
//    // 给主队列设置一个标记
//
//    dispatch_queue_set_specific(mainQueue, "key", "main", NULL);
//
//    // 定义一个block任务
//
//    dispatch_block_t log = ^{
//
//        // 判断是否是主线程
//
//        NSLog(@"main thread: %d", [NSThread isMainThread]);
//
//        // 判断是否是主队列
//
//        void *value = dispatch_get_specific("key");
//
//        NSLog(@"main queue: %d", value != NULL);
//
//    };
//
//
//    // 异步加入全局队列里
//
//    dispatch_async(globalQueue, ^{
//
//        // 异步加入主队列里
//
//        dispatch_async(dispatch_get_main_queue(), log);
//
//    });
//
//    NSLog(@"before dispatch_main");
//
//    dispatch_main();
//
//    NSLog(@"after dispatch_main");
//#elif 0
//    // 同步加入全局队列里
//
//    dispatch_sync(globalQueue, ^{
//
//    // 判断是否是主线程
//
//    NSLog(@"main thread: %d", [NSThread isMainThread]);
//
//    // 判断是否是主队列
//
//    void *value = dispatch_get_specific("key");
//
//    NSLog(@"main queue: %d", value != NULL);
//
//    });
//#else
//        dispatch_queue_t concurrentQueue = dispatch_queue_create("concurrentQueue", DISPATCH_QUEUE_CONCURRENT);
//
//        dispatch_async(concurrentQueue, ^{
//            for (NSInteger i = 0; i < 1000; i++) {
//                NSLog(@"currentThread = %@, i = %ld", [NSThread currentThread], (long) i);
//            }
//        });
//#endif
    return YES;
}

@end
