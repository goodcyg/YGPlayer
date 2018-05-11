#import <Foundation/Foundation.h>
#import "HTTPResponse.h"

@class HTTPConnection;


@interface HTTPFileResponse : NSObject <HTTPResponse>
{
	HTTPConnection *connection;
    /**
     *  文件名
     */
	NSString *filePath;
    /**
     *  文件长度
     */
	UInt64 fileLength;
    /**
     *  当前的偏移量
     */
	UInt64 fileOffset;
	
	BOOL aborted;
	
    /**
     *  文件句柄
     */
	int fileFD;
    /**
     *  buffer缓存
     */
	void *buffer;
    /**
     *  缓存大小
     */
	NSUInteger bufferSize;
}

- (id)initWithFilePath:(NSString *)filePath forConnection:(HTTPConnection *)connection;
- (NSString *)filePath;

@end
