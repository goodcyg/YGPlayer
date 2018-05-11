#import "YGCodeConfound.h"
#import "HTTPFileResponse.h"
#import "HTTPConnection.h"
#import "HTTPLogging.h"
#import "FTXConfigManger.h"

#import <fcntl.h>
#import <unistd.h>

#if !__has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels : off, error, warn, info, verbose
// Other flags: trace
static const int httpLogLevel = HTTP_LOG_LEVEL_ERROR|HTTP_LOG_LEVEL_WARN | HTTP_LOG_FLAG_VERBOSE;

#define NULL_FD -1

@implementation HTTPFileResponse

- (id)initWithFilePath:(NSString*)fpath forConnection:(HTTPConnection*)parent
{
    if ((self = [super init])) {
        HTTPLogTrace();

        connection = parent; // Parents retain children, children do NOT retain parents

        fileFD = NULL_FD;
        filePath = [[fpath copy] stringByResolvingSymlinksInPath];
        HTTPLogInfo(@"fpath:%@ --filePath:%@",fpath,filePath);
        if (filePath == nil) {
            HTTPLogWarn(@"%@: Init failed - Nil filePath", THIS_FILE);

            return nil;
        }

        NSDictionary* fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
        if (fileAttributes == nil) {
            HTTPLogWarn(@"%@: Init failed - Unable to get file attributes. filePath: %@", THIS_FILE, filePath);

            return nil;
        }

        //上传文件
        if ([[FTXConfigManger sharedConfigManger] WiFiFileShareEnable]) {
            fileLength = (UInt64)[[fileAttributes objectForKey:NSFileSize] unsignedLongLongValue];
            HTTPLogError(@"upload file fileLength:%lld",fileLength);
        } else
        {
            //本地缓冲
            fileLength = [[FTXConfigManger sharedConfigManger] HttpFileLength];
             HTTPLogError(@"local file fileLength:%lld",fileLength);
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

- (BOOL)openFile
{
    HTTPLogTrace();

    fileFD = open([filePath UTF8String], O_RDONLY);
    if (fileFD == NULL_FD) {
        HTTPLogError(@"%@[%p]: Unable to open file. filePath: %@", THIS_FILE, self, filePath);

        [self abort];
        return NO;
    }

    HTTPLogVerbose(@"%@[%p]: Open fd[%i] -> %@", THIS_FILE, self, fileFD, filePath);

    return YES;
}

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
        return YES;
    }

    return [self openFile];
}

- (UInt64)contentLength
{
    HTTPLogTrace();

    return fileLength;
}

- (UInt64)offset
{
    HTTPLogTrace();

    return fileOffset;
}

- (void)setOffset:(UInt64)offset
{
    HTTPLogTrace2(@"%@[%p]: setOffset:%llu", THIS_FILE, self, offset);

    if (![self openFileIfNeeded]) {
        // File opening failed,
        // or response has been aborted due to another error.
        HTTPLogError(@"%@ File opening failed", THIS_FILE);
        return;
    }

    fileOffset = offset;

    off_t result = lseek(fileFD, (off_t)offset, SEEK_SET);
    if (result == -1) {
        HTTPLogError(@"%@[%p]: lseek failed - errno(%i) filePath(%@)", THIS_FILE, self, errno, filePath);

        [self abort];
    }
}

- (NSData*)readDataOfLength:(NSUInteger)length
{
    HTTPLogTrace2(@"%@[%p]: readDataOfLength:%lu", THIS_FILE, self, (unsigned long)length);

    if (![self openFileIfNeeded]) {
        // File opening failed,
        // or response has been aborted due to another error.
        HTTPLogError(@"%@ File opening failed", THIS_FILE);
        return nil;
    }

    // Determine how much data we should read.
    //
    // It is OK if we ask to read more bytes than exist in the file.
    // It is NOT OK to over-allocate the buffer.
    //文件剩余字节数
    UInt64 bytesLeftInFile = fileLength - fileOffset;
    //文件剩余字节和读取字节数中取最小的
    NSUInteger bytesToRead = (NSUInteger)MIN(length, bytesLeftInFile);
    
    HTTPLogTrace2(@"%@[%p]: bytesLeftInFile:%llu bytesToRead:%ld", THIS_FILE, self, bytesLeftInFile,(unsigned long)bytesToRead);
    
    // Make sure buffer is big enough for read request.
    // Do not over-allocate.

    if (buffer == NULL || bufferSize < bytesToRead) {
        bufferSize = bytesToRead;
        //重新分配缓存
        buffer = reallocf(buffer, (size_t)bufferSize);

        if (buffer == NULL) {
            HTTPLogError(@"%@[%p]: Unable to allocate buffer", THIS_FILE, self);

            [self abort];
            return nil;
        }
    }

    // Perform the read

    HTTPLogVerbose(@"%@[%p]: Attempting to read %lu bytes from file", THIS_FILE, self, (unsigned long)bytesToRead);
     //读取数据
    ssize_t result = read(fileFD, buffer, bytesToRead);

    // Check the results

    if (result < 0) {
        HTTPLogError(@"%@: Error(%i) reading file(%@)", THIS_FILE, errno, filePath);

        [self abort];
        return nil;
    } else if (result == 0) {
        HTTPLogError(@"%@: Read EOF on file(%@)", THIS_FILE, filePath);

        [self abort];
        return nil;
    } else // (result > 0)
    {
        HTTPLogVerbose(@"%@[%p]: Read %ld bytes from file", THIS_FILE, self, (long)result);

        fileOffset += result;
         //进行包装
        return [NSData dataWithBytes:buffer length:result];
    }
}

- (BOOL)isDone
{
    BOOL result = (fileOffset == fileLength);

    HTTPLogTrace2(@"%@[%p]: isDone - %@", THIS_FILE, self, (result ? @"YES" : @"NO"));

    return result;
}

- (NSString*)filePath
{
    return filePath;
}

- (void)dealloc
{
    HTTPLogTrace();

    if (fileFD != NULL_FD) {
        HTTPLogVerbose(@"%@[%p]: Close fd[%i]", THIS_FILE, self, fileFD);

        close(fileFD);
    }

    if (buffer)
        free(buffer);
}

@end
