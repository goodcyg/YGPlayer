//
//  AppDelegate+httpserver.m
//  VIMediaCacheDemo
//
//  Created by Jackson on 2018/5/10.
//  Copyright © 2018年 Vito. All rights reserved.
//

#import "App+httpserver.h"
#import "SGWiFiUploadManager.h"
#import "FTXConfigManger.h"
#import "HYFileManager.h"
@implementation Apphttpserver
-(NSString*)documentsDir
{
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
}
- (NSString*)cachesDir
{
    return [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
}
- (void)setupServer
{
    SGWiFiUploadManager* mgr = [SGWiFiUploadManager sharedManager];
    // mgr.savePath = [self documentsDir];
    
    NSString* webPath = [[self documentsDir] stringByAppendingPathComponent:@"videoCache"];
#if 0
    NSFileManager* fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:webPath]) {
        [fileManager createDirectoryAtPath:webPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    NSString* webPath2 = [webPath stringByAppendingPathComponent:@"tmp.mp4"];
    if ([fileManager fileExistsAtPath:webPath2]) {
        LOG(@"%@", webPath2);
    }
#endif
    //拷贝资源
    [self copyHtmlResource:@"index.html" webPath:webPath];
    [self copyHtmlResource:@"upload.html" webPath:webPath];
    
    mgr.savePath = webPath;
    mgr.webPath = webPath;
    [[FTXConfigManger sharedConfigManger] WiFiFileShareOn];
    BOOL success = [mgr startHTTPServerAtPort:10086];
    
    if (success) {
        
       NSLog(@"URL = %@:%@", mgr.ip, @(mgr.port));
       
    }
    

}

- (void)copyHtmlResource:(NSString*)htmlName webPath:(NSString*)webPath
{
    if (htmlName.length == 0 || webPath.length == 0) {
        //LOG_ERROR(@"copy resource fali...");
        return;
    }
    NSString* resourceDir = [[NSBundle mainBundle] resourcePath];
    NSString* indexFileName = [resourceDir stringByAppendingPathComponent:htmlName];
    NSString* newindexFileName = [webPath stringByAppendingPathComponent:htmlName];
    if (![HYFileManager isExistsAtPath:newindexFileName]) {
        [HYFileManager copyItemAtPath:indexFileName toPath:newindexFileName];
    }
}

@end
