#import "HTTPAsyncFileResponse.h"
#import "HTTPConnection.h"
#import "HTTPLogging.h"
#import "YGCodeConfound.h"
#import "FTXConfigManger.h"

#import <fcntl.h>
#import <unistd.h>
#import <pthread.h>

#if !__has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels : off, error, warn, info, verbose
// Other flags: trace
#if 1
static const int httpLogLevel =HTTP_LOG_LEVEL_OFF;
#else
static const int httpLogLevel = HTTP_LOG_LEVEL_VERBOSE | HTTP_LOG_LEVEL_ERROR | HTTP_LOG_LEVEL_INFO | HTTP_LOG_LEVEL_WARN | HTTP_LOG_FLAG_TRACE;
#endif
#define NULL_FD -1

/**
 * Architecure overview:
 * 
 * HTTPConnection will invoke our readDataOfLength: method to fetch data.
 * We will return nil, and then proceed to read the data via our readSource on our readQueue.
 * Once the requested amount of data has been read, we then pause our readSource,
 * and inform the connection of the available data.
 * 
 * While our read is in progress, we don't have to worry about the connection calling any other methods,
 * except the connectionDidClose method, which would be invoked if the remote end closed the socket connection.
 * To safely handle this, we do a synchronous dispatch on the readQueue,
 * and nilify the connection as well as cancel our readSource.
 * 
 * In order to minimize resource consumption during a HEAD request,
 * we don't open the file until we have to (until the connection starts requesting data).
**/

@implementation HTTPAsyncFileResponse

- (id)initWithFilePath:(NSString*)fpath forConnection:(HTTPConnection*)parent
{
    if ((self = [super init])) {
        HTTPLogTrace3(@"NO_100");

        connection = parent; // Parents retain children, children do NOT retain parents

        fileFD = NULL_FD;
        //拷贝副本，防止文件改变
        filePath = [fpath copy];
        if (filePath == nil) {
            HTTPLogWarn(@"%@: Init failed - Nil filePath", THIS_FILE);

            return nil;
        }

        //获取文件属性
        NSDictionary* fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:NULL];
        if (fileAttributes == nil) {
            HTTPLogWarn(@"%@: Init failed - Unable to get file attributes. filePath: %@", THIS_FILE, filePath);

            return nil;
        }

        HTTPLogInfo(@"file:%@", filePath);

        //fileLength = (UInt64)[[fileAttributes objectForKey:NSFileSize] unsignedLongLongValue];

        //上传文件
        if ([[FTXConfigManger sharedConfigManger] WiFiFileShareEnable]) {
            fileLength = (UInt64)[[fileAttributes objectForKey:NSFileSize] unsignedLongLongValue];
            HTTPLogInfo(@"file fileLength:%lld", fileLength);
        } else {
            //本地缓冲
            fileLength = [[FTXConfigManger sharedConfigManger] HttpFileLength];
            HTTPLogError(@"local file fileLength:%lld", fileLength);
        }

        fileOffset = 0;

        aborted = NO;

        // We don't bother opening the file here.
        // If this is a HEAD request we only need to know the fileLength.
    }
    return self;
}

- (void)abort
{
    HTTPLogTrace();

    [connection responseDidAbort:self];
    aborted = YES;
}

- (void)processReadBuffer
{
    // This method is here to allow superclasses to perform post-processing of the data.
    // For an example, see the HTTPDynamicFileResponse class.
    //
    // At this point, the readBuffer has readBufferOffset bytes available.
    // This method is in charge of updating the readBufferOffset.
    // Failure to do so will cause the readBuffer to grow to fileLength. (Imagine a 1 GB file...)

    // Copy the data out of the temporary readBuffer.
    data = [[NSData alloc] initWithBytes:readBuffer length:readBufferOffset];

    // Reset the read buffer.
    readBufferOffset = 0;

    // Notify the connection that we have data available for it.
    //通知connection有数据
    [connection responseHasAvailableData:self];
}

- (void)pauseReadSource
{
    if (!readSourceSuspended) {
        HTTPLogVerbose(@"%@[%p]: Suspending readSource", THIS_FILE, self);

        readSourceSuspended = YES;
        //暂停读取源队列
        dispatch_suspend(readSource);
    }
}

- (void)resumeReadSource
{
    if (readSourceSuspended) {
        HTTPLogVerbose(@"%@[%p]: Resuming readSource", THIS_FILE, self);

        readSourceSuspended = NO;
        //恢复读取源队列
        dispatch_resume(readSource);
    }
}

- (void)cancelReadSource
{
    HTTPLogVerbose(@"%@[%p]: Canceling readSource", THIS_FILE, self);
    //取消源队列
    dispatch_source_cancel(readSource);

    // Cancelling a dispatch source doesn't
    // invoke the cancel handler if the dispatch source is paused.

    if (readSourceSuspended) {
        readSourceSuspended = NO;
        //恢复读取源队列
        dispatch_resume(readSource);
    }
}

/*
dispatch源（dispatch source）和RunLoop源概念上有些类似的地方，而且使用起来更简单。要很好地理解dispatch源，其实把它看成一种特别的生产消费模式。dispatch源好比生产的数据，当有新数据时，会自动在dispatch指定的队列（即消费队列）上运行相应地block，生产和消费同步是dispatch源会自动管理的。
dispatch源的使用基本为以下步骤：

1. dispatch_source_t source = dispatch_source_create(dispatch_source_type, handler, mask, dispatch_queue); //创建dispatch源，这里使用加法来合并dispatch源数据，最后一个参数是指定dispatch队列

2. dispatch_source_set_event_handler(source, ^{ //设置响应dispatch源事件的block，在dispatch源指定的队列上运行
    
    　　//可以通过dispatch_source_get_data(source)来得到dispatch源数据
    
});

3. dispatch_resume(source); //dispatch源创建后处于suspend状态，所以需要启动dispatch源

4. dispatch_source_merge_data(source, value); //合并dispatch源数据，在dispatch源的block中，dispatch_source_get_data(source)就会得到value。
*/
#pragma mark - 读取文件数据
- (BOOL)openFileAndSetupReadSource
{
    HTTPLogTrace();

    fileFD = open([filePath UTF8String], (O_RDONLY | O_NONBLOCK));
    if (fileFD == NULL_FD) {
        HTTPLogError(@"%@: Unable to open file. filePath: %@", THIS_FILE, filePath);

        return NO;
    }

    HTTPLogVerbose(@"%@[%p]: Open fd[%i] -> %@", THIS_FILE, self, fileFD, filePath);
    //创建串行队列
    readQueue = dispatch_queue_create("HTTPAsyncFileResponse", NULL);
    //创建源
    readSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, fileFD, 0, readQueue);
    //创建源事件
    dispatch_source_set_event_handler(readSource, ^{

        //HTTPLogTrace2(@"22222 %@: eventBlock - fd[%i]", THIS_FILE, fileFD);

        // Determine how much data we should read.
        //
        // It is OK if we ask to read more bytes than exist in the file.
        // It is NOT OK to over-allocate the buffer.
        //返回文件大小
        unsigned long long _bytesAvailableOnFD = dispatch_source_get_data(readSource);
        //剩余的数据
        UInt64 _bytesLeftInFile = fileLength - readOffset;

        //设置有效数据的范围
        NSUInteger bytesAvailableOnFD = (_bytesAvailableOnFD > NSUIntegerMax) ? NSUIntegerMax : (NSUInteger)_bytesAvailableOnFD;
        //设置剩余数据的范围
        NSUInteger bytesLeftInFile = (_bytesLeftInFile > NSUIntegerMax) ? NSUIntegerMax : (NSUInteger)_bytesLeftInFile;
        //剩余请求的数据
        NSUInteger bytesLeftInRequest = readRequestLength - readBufferOffset;
        //设置剩余数据和剩余请求数据的有效大小
        NSUInteger bytesLeft = MIN(bytesLeftInRequest, bytesLeftInFile);
        //设置读取数据的有效大小
        NSUInteger bytesToRead = MIN(bytesAvailableOnFD, bytesLeft);

        // Make sure buffer is big enough for read request.
        // Do not over-allocate.
        //如果缓存不够，重新分配大小
        if (readBuffer == NULL || bytesToRead > (readBufferSize - readBufferOffset)) {
            readBufferSize = bytesToRead;
            readBuffer = reallocf(readBuffer, (size_t)bytesToRead);
            //数据缓存分配失败
            if (readBuffer == NULL) {
                HTTPLogError(@"%@[%p]: Unable to allocate buffer", THIS_FILE, self);

                [self pauseReadSource];
                [self abort];

                return;
            }
        }

        // Perform the read

        HTTPLogVerbose(@"%@[%p]: Attempting to read %lu bytes from file", THIS_FILE, self, (unsigned long)bytesToRead);

        //读取数据
        ssize_t result = read(fileFD, readBuffer + readBufferOffset, (size_t)bytesToRead);
      
        //if (fileOffset>=675834763)
     
        
//        printf("request 读取 fileOffset:%llu read: %lu to %llu/%llu bytes thread_id:%lu ",fileOffset, (unsigned long)result, fileOffset+(unsigned long)result,fileLength,(unsigned long)pthread_self());
        
        //debugHexLog((unsigned char*)(readBuffer + readBufferOffset), 20, @"读取data:");

        // Check the results
        if (result < 0) {
            HTTPLogError(@"%@: Error(%i) reading file(%@)", THIS_FILE, errno, filePath);

            [self pauseReadSource];
            [self abort];
        } else if (result == 0) {
            HTTPLogError(@"%@: Read EOF on file(%@)", THIS_FILE, filePath);

            [self pauseReadSource];
            [self abort];
        } else // (result > 0)
        {
            HTTPLogVerbose(@"%@[%p]:111111111 Read %lu bytes from file", THIS_FILE, self, (unsigned long)result);

            //设置偏移大小
            readOffset += result;
            readBufferOffset += result;
            //暂停数据读取
            [self pauseReadSource];
            //处理数据的读取
            [self processReadBuffer];
        }

    });

    int theFileFD = fileFD;
    
#if !OS_OBJECT_USE_OBJC
    dispatch_source_t theReadSource = readSource;
#endif
 
    //设置源取消
    dispatch_source_set_cancel_handler(readSource, ^{

        // Do not access self from within this block in any way, shape or form.
        //
        // Note: You access self if you reference an iVar.

        HTTPLogTrace2(@"%@: cancelBlock - Close fd[%i]", THIS_FILE, theFileFD);

#if !OS_OBJECT_USE_OBJC
        dispatch_release(theReadSource);
#endif
        close(theFileFD);
    });

    readSourceSuspended = YES;

    return YES;
}

/**
 *  是否需要读取文件
 *
 *  @return NO：不需要 YES:需要
 */
- (BOOL)openFileIfNeeded
{
    if (aborted) {
        // The file operation has been aborted.
        // This could be because we failed to open the file,
        // or the reading process failed.
        return NO;
    }

    if (fileFD != NULL_FD) {
        // File has already been opened.
        HTTPLogTrace2(@"File has already been opened.");
        return YES;
    }
    //打开文件设置读取源
    return [self openFileAndSetupReadSource];
}

- (UInt64)contentLength
{
    HTTPLogTrace2(@"NO_200 %@[%p]: contentLength - %llu", THIS_FILE, self, fileLength);
    //返回文件长度
    return fileLength;
}

- (UInt64)offset
{
    HTTPLogTrace2(@"NO_400 %@[%p]: contentLength - %llu", THIS_FILE, self, fileLength);

    //HTTPLogTrace();
    //返回文件偏移量
    return fileOffset;
}

- (void)setOffset:(UInt64)offset
{

    HTTPLogTrace2(@"NO_300 %@[%p]: setOffset:%llu", THIS_FILE, self, offset);
    
   // NSLog(@"request NO_300 currentThread%@ setOffset:%llu", [NSThread currentThread], offset);
 
    if (![self openFileIfNeeded]) {
        // File opening failed,
        // or response has been aborted due to another error.
        return;
    }
    //设置文件偏移量
    fileOffset = offset;
    readOffset = offset;
    
    
    //if (offset>=675834763)
  

    off_t result = lseek(fileFD, (off_t)offset, SEEK_SET);
    //printf("%s setOffset:%llu \n",__FUNCTION__, offset);
    if (result == -1) {
        HTTPLogError(@"%@[%p]: lseek failed - errno(%i) filePath(%@)", THIS_FILE, self, errno, filePath);

        [self abort];
    }
}

- (NSData*)readDataOfLength:(NSUInteger)length
{
    HTTPLogTrace2(@"NO_500 %@[%p]: readDataOfLength:%lu", THIS_FILE, self, (unsigned long)length);

    if (data) {
        //如果缓存有数据直接返回读取到数据
        NSUInteger dataLength = [data length];

        HTTPLogVerbose(@"%@[%p]: Returning data of length %lu", THIS_FILE, self, (unsigned long)dataLength);
        //设置文件的偏移
        fileOffset += dataLength;

        NSData* result = data;
        data = nil;

        return result;
    } else {
        //如果缓存无数据

        if (![self openFileIfNeeded]) {
            // File opening failed,
            // or response has been aborted due to another error.
            return nil;
        }

        dispatch_sync(readQueue, ^{

            NSAssert(readSourceSuspended, @"Invalid logic - perhaps HTTPConnection has changed.");
            HTTPLogTrace2(@"111:readDataOfLength:%lu", (unsigned long)length);
            //设置读取长度
            readRequestLength = length;
          //  LOG4(@"读取source数据");
            //恢复源读取数据
            [self resumeReadSource];
        });

        return nil;
    }
}

- (BOOL)isDone
{
    //读取是否完成
    BOOL result = (fileOffset == fileLength);

    HTTPLogTrace2(@"NO_600 %@[%p]: isDone - %@", THIS_FILE, self, (result ? @"YES" : @"NO"));

    return result;
}

- (NSString*)filePath
{
    return filePath;
}

- (BOOL)isAsynchronous
{

    return YES;
}

- (void)connectionDidClose
{
    HTTPLogTrace3(@"NO_700");

    if (fileFD != NULL_FD) {
        dispatch_sync(readQueue, ^{

            // Prevent any further calls to the connection
            connection = nil;

            // Cancel the readSource.
            // We do this here because the readSource's eventBlock has retained self.
            // In other words, if we don't cancel the readSource, we will never get deallocated.

            [self cancelReadSource];
        });
    }
}

- (void)dealloc
{

#if !OS_OBJECT_USE_OBJC
    if (readQueue)
        dispatch_release(readQueue);
#endif

    if (readBuffer)
        free(readBuffer);
}

@end
