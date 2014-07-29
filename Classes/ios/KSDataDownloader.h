//
//  KSDataDownloader.h
//
//  Created by Kai Straßmann on 24.10.13.
//

#import <Foundation/Foundation.h>

#define KSDataDownloaderInvalidUrlErrorCode -1
#define KSDataDownloaderBackgroundTaskNoTimeLeftErrorCode -2

@interface KSDataDownloader : NSObject <NSURLConnectionDataDelegate>
@property (nonatomic, strong, readonly) NSURLConnection *urlConnection;
@property (nonatomic, strong, readonly) NSHTTPURLResponse *urlResponse;
@property (nonatomic, assign) int timeoutSeconds;
@property (nonatomic, copy) NSString *method;
@property (nonatomic, copy) void (^progressBlock)(KSDataDownloader *downloader, float progress);
@property (nonatomic, copy) void (^uploadProgressBlock)(KSDataDownloader *downloader, float progress);
@property (nonatomic, assign) BOOL disableCookies;
@property (nonatomic, assign) BOOL disableBackgroundDownload;

- (id)initWithCompletionBlock:(void(^)(KSDataDownloader *downloader, NSData *data, NSString *stringData))success error:(void(^)(KSDataDownloader *downloader, NSError*error))error;
- (id)initWithJSONCompletionBlock:(void(^)(KSDataDownloader *downloader, id responseObject))success error:(void(^)(KSDataDownloader *downloader, NSError*error))error;
- (id)initWithTargetFileUrl:(NSURL*)targetFileUrl completion:(void(^)(KSDataDownloader *downloader))success error:(void(^)(KSDataDownloader *downloader, NSError*error))error;

- (void)setHeader:(NSString*)value forKey:(NSString*)key;
- (void)removeHeaderForKey:(NSString*)key;
+ (void)setGlobalHeader:(NSString*)value forKey:(NSString*)key;
+ (void)removeGlobalHeaderForKey:(NSString*)key;

- (void)setUsername:(NSString*)username andPassword:(NSString*)password;

- (void)startRequest:(NSURL *)url;
- (void)startRequest:(NSURL *)url parameters:(NSDictionary*)parameters;
- (void)startRequest:(NSURL *)url httpBodyData:(NSData*)httpBodyData;
- (void)cancelDownload;

- (NSData*)downloadedData;

+ (void)setUseNetworkActivityIndicatorManager:(BOOL)showIndicator;
@end
