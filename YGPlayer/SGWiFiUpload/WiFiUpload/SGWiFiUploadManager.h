//
//  SGWiFiUploadManager.h
//  SGWiFiUpload
//
//  Created by soulghost on 29/6/2016.
//  Copyright © 2016 soulghost. All rights reserved.
//
#import "YGCodeConfound.h"
#import "HTTPServer.h"
#import "SGConst.h"
#import <UIKit/UIKit.h>

@interface SGWiFiUploadManager : NSObject

@property (nonatomic, strong) HTTPServer* httpServer;
@property (nonatomic, copy) NSString* savePath;
@property (nonatomic, copy) NSString* webPath;

@property (nonatomic, strong) UIViewController* viewController;

+ (instancetype)sharedManager;
+ (NSString*)ip;

- (BOOL)startHTTPServerAtPort:(UInt16)port;
- (void)startHTTPServer:(HTTPServer*)server;
- (BOOL)isServerRunning;
- (void)stopHTTPServer;
- (NSString*)ip;
- (UInt16)port;
- (void)showWiFiPageFrontViewController:(UIViewController*)viewController;

@end
