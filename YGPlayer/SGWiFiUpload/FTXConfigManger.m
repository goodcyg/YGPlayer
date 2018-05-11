//
//  FTXConfigManger.m
//  iDiskk
//
//  Created by Jackson on 2017/2/9.
//  Copyright © 2017年 Jackson. All rights reserved.
//

#import "FTXConfigManger.h"
//#import "FTXVideoConfig.h"
/**
 *  视频配置信息
 */
static NSString* const kUserVideoConfigKey = @"com.ftx.videoConfig";
/**
 *  WiFi共享
 */
static NSString* const kFileUploadConfigKey = @"com.ftx.fileUpload";
/**
 *  文件大小
 */
static NSString* const kFileLengthConfigKey = @"com.ftx.fileLength";
/**
 *  文件的浏览模式
 */
static NSString* const kFileBrowseModeConfigKey = @"com.ftx.FileBrowseMode";

@interface FTXConfigManger ()
@property (nonatomic, weak) NSUserDefaults* userDefaults;
/**
 *  App文件
 */
@property (nonatomic, weak) NSMutableArray* appArray;
/**
 *  iDiskk文件
 */
@property (nonatomic, weak) NSMutableArray* iDiskkArray;
@end

@implementation FTXConfigManger

static FTXConfigManger* _sharedInstance;

+ (FTXConfigManger*)sharedConfigManger
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [FTXConfigManger new];
        _sharedInstance.userDefaults = [NSUserDefaults standardUserDefaults];
    });

    return _sharedInstance;
}
+ (id)copyWithZone:(struct _NSZone*)zone
{
    return _sharedInstance;
}
- (void)videoWithConfig:(FTXVideoConfig*)videoConfig
{
    if (!videoConfig) {
        return;
    }
    NSData* data = [NSKeyedArchiver archivedDataWithRootObject:videoConfig];
    [_userDefaults setObject:data forKey:kUserVideoConfigKey];
    [_userDefaults synchronize];
}

- (void)WiFiFileShareOn
{
    [_userDefaults setInteger:1 forKey:kFileUploadConfigKey];
}
- (void)WiFiFileShareOff
{
    [_userDefaults setInteger:0 forKey:kFileUploadConfigKey];
}

- (BOOL)WiFiFileShareEnable
{
    return ([[_userDefaults objectForKey:kFileUploadConfigKey] integerValue] == 1);
}

//- (FTXVideoConfig*)videoConfig
//{
//    NSData* data = [_userDefaults objectForKey:kUserVideoConfigKey];
//    if (data)
//        return [NSKeyedUnarchiver unarchiveObjectWithData:data];
//    return [FTXVideoConfig defaultVideoConfig];
//}

- (UInt64)HttpFileLength
{
    return (UInt64)[_userDefaults doubleForKey:kFileLengthConfigKey];
}

- (void)setHttpFileLength:(double)size
{
    [_userDefaults setDouble:size forKey:kFileLengthConfigKey];
}
#pragma mark -截图失败
- (void)setThumbnailFail:(NSString*)key
{
    [_userDefaults setInteger:1 forKey:key];
}
#pragma mark -截图失败
- (BOOL)getThumbnailFail:(NSString*)key
{
    return ([_userDefaults integerForKey:key] == 10);
}
- (void)setAppArray:(NSMutableArray*)appArray
{
    _appArray = appArray;
}
- (NSMutableArray*)getAppArray
{
    return _appArray;
}
- (void)setiDiskkArray:(NSMutableArray*)iDiskkArray
{
    _iDiskkArray = iDiskkArray;
}
- (NSMutableArray*)getiDiskkArray
{
    return _iDiskkArray;
}
///**
// *  设置文件的浏览模式
// */
//-(void)setFileBrowseMode:(FTXFileBrowseMode)mode
//{
//     [_userDefaults setInteger:mode forKey:kFileBrowseModeConfigKey];
//}
///**
// *  获取文件的浏览模式
// */
//-(FTXFileBrowseMode)getFileBrowseMode
//{
//    return (FTXFileBrowseMode)[_userDefaults integerForKey:kFileBrowseModeConfigKey];
//}

@end
