//
//  FTXConfigManger.h
//  iDiskk
//
//  Created by Jackson on 2017/2/9.
//  Copyright © 2017年 Jackson. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FTXVideoConfig;

@interface FTXConfigManger : NSObject
+ (FTXConfigManger*)sharedConfigManger;
- (void)videoWithConfig:(FTXVideoConfig*)videoConfig;
//- (FTXVideoConfig*)videoConfig;
/**
 *  打开WiFi文件共享
 */
- (void)WiFiFileShareOn;
/**
 *  关闭WiFi文件共享
 */
- (void)WiFiFileShareOff;
/**
 *  WiFi文件共享是否有效
 *
 *  @return YES 有效
 */
- (BOOL)WiFiFileShareEnable;
/**
 *  获取文件大小
 *
 *  @return 大小
 */
- (UInt64)HttpFileLength;
/**
 *  设置文件大小
 *
 *  @param size 大小
 */
- (void)setHttpFileLength:(double)size;
/**
 *  截图失败
 *
 *  @param key md5
 */
- (void)setThumbnailFail:(NSString*)key;
/**
 *  截图失败
 *
 *  @param key md5
 *
 *  @return <#return value description#>
 */
- (BOOL)getThumbnailFail:(NSString*)key;
/**
 *  设置app模型数组
 *
 *  @param appArray 模型数组
 */
- (void)setAppArray:(NSMutableArray*)appArray;
/**
 *  获取app模型数组
 *
 *  @return 模型数组
 */
- (NSMutableArray*)getAppArray;
/**
 *  设置iDiskk模型数组
 *
 *  @param iDiskkArray 模型数组
 */
- (void)setiDiskkArray:(NSMutableArray*)iDiskkArray;
/**
 *  获取iDiskk模型数组
 *
 *  @return 模型数组
 */
- (NSMutableArray*)getiDiskkArray;


@end
