//
//  KSDataDownloader.m
//
//  Created by Kai Straßmann on 24.10.13.
//

#import "KSDataDownloader.h"
#import "KSNetworkActivityIndicatorManager.h"

@interface KSDataDownloader ()
@property (nonatomic, strong) NSURLConnection *urlConnection;
@property (nonatomic, strong) NSHTTPURLResponse *urlResponse;
@property (nonatomic, assign) long long contentLength;
@property (nonatomic, strong) NSMutableData *activeDownloadData;
@property (nonatomic, assign) BOOL operationEnded;
@property (nonatomic, copy) void (^successBlock)(KSDataDownloader *downloader, NSData *data, NSString *stringData);
@property (nonatomic, copy) void (^fileSuccessBlock)(KSDataDownloader *downloader);
@property (nonatomic, copy) void (^jsonSuccessBlock)(KSDataDownloader *downloader, id responseObject);
@property (nonatomic, copy) void (^errorBlock)(KSDataDownloader *downloader, NSError *error);
@property (nonatomic, strong) NSURLCredential *credential;
@property (nonatomic, copy) NSURL *targetFileUrl;
@property (nonatomic, copy) NSURL *tmpFileUrl;
@property (nonatomic, strong) NSOutputStream *outputStream;
@property (nonatomic, assign) long long outputStreamBytesWritten;
@property (nonatomic, strong) NSMutableDictionary *headers;
@property (nonatomic, assign) UIBackgroundTaskIdentifier backgroundTaskIdentifier;
@end

static NSMutableDictionary *globalHeaders;
static BOOL useNetworkActivityIndicatorManager;

@implementation KSDataDownloader
+ (void)initialize {
    if (self == [KSDataDownloader class]) {
        globalHeaders = [NSMutableDictionary dictionary];
		useNetworkActivityIndicatorManager = YES;
    }
}

- (id)initWithCompletionBlock:(void(^)(KSDataDownloader *downloader, NSData *data, NSString *stringData))success error:(void(^)(KSDataDownloader *downloader, NSError *error))error {
	self = [super init];
	if (self) {
		self.successBlock = success;
		self.errorBlock = error;
		[self setDefaults];
	}
	return self;
}

- (id)initWithJSONCompletionBlock:(void(^)(KSDataDownloader *downloader, id responseObject))success error:(void(^)(KSDataDownloader *downloader, NSError*error))error {
	self = [super init];
	if (self) {
		self.jsonSuccessBlock = success;
		self.errorBlock = error;
		[self setDefaults];
		self.headers[@"Accept"] = @"application/json,text/json";
	}
	return self;
}

- (id)initWithTargetFileUrl:(NSURL*)targetFileUrl completion:(void(^)(KSDataDownloader *downloader))success error:(void(^)(KSDataDownloader *downloader, NSError*error))error {
	self = [super init];
	if (self) {
		self.fileSuccessBlock = success;
		self.errorBlock = error;
		[self setDefaults];
		self.targetFileUrl = targetFileUrl;
	}
	return self;
}

- (void)setDefaults {
	self.timeoutSeconds = 90;
	self.method = @"GET";
	self.headers = [NSMutableDictionary dictionary];
	self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
	
	for (NSString *key in globalHeaders) {
		self.headers[key] = globalHeaders[key];
	}
}

#pragma mark - Cancel
- (void)cancelDownload {
	if (!self.operationEnded) {
		self.operationEnded = YES;
		if (useNetworkActivityIndicatorManager) [[KSNetworkActivityIndicatorManager sharedManager] decrease];
	}
	
	[self.urlConnection cancel];
	self.urlConnection = nil;
	self.activeDownloadData = nil;
	self.urlResponse = nil;
	if (self.backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
		[[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskIdentifier];
		self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
	}
}

#pragma mark - Request startes
- (void)startRequest:(NSURL *)url parameters:(NSDictionary*)parameters httpBodyData:(NSData*)bodyData {
	if (url == nil) {
		if (self.errorBlock) self.errorBlock(self, [NSError errorWithDomain:@"KSDataDownloader" code:KSDataDownloaderInvalidUrlErrorCode userInfo:@{NSLocalizedDescriptionKey: @"url can't be nil!"}]);
		return;
	}
	
	self.operationEnded = NO;
	if (self.targetFileUrl) { // download to file
		// generate a tmp target file
		NSString *guid = [[[NSUUID alloc] init] UUIDString];
		NSString *tmpPath = NSTemporaryDirectory();
		self.tmpFileUrl = [[NSURL fileURLWithPath:tmpPath] URLByAppendingPathComponent:guid];
		self.outputStream = [NSOutputStream outputStreamWithURL:self.tmpFileUrl append:NO];
		[self.outputStream open];
		self.outputStreamBytesWritten = 0;
	} else { // download to memory
		self.activeDownloadData = [NSMutableData data];
	}
	
	self.urlResponse = nil;
	if (useNetworkActivityIndicatorManager) [[KSNetworkActivityIndicatorManager sharedManager] increase];
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:self.timeoutSeconds];
	request.HTTPMethod = self.method;
	
	// enable/disable cookies
	[request setHTTPShouldHandleCookies:!self.disableCookies];
		
	for (NSString *key in self.headers) {
		[request setValue:self.headers[key] forHTTPHeaderField:key];
	}
	
	if (parameters) {
		NSMutableString *queryString = [[NSMutableString alloc] init];
		for (NSString *key in parameters) {
			id unknownTypeValue = parameters[key];
			
			NSString *value;
			if ([unknownTypeValue isKindOfClass:[NSString class]]) {
				value = unknownTypeValue;
				[queryString appendFormat:@"%@=%@&", key, [self urlEncode:value]];
			} else if ([unknownTypeValue isKindOfClass:[UIImage class]]) {
				NSLog(@"not implemented yet");
			} else if ([unknownTypeValue isKindOfClass:[NSNull class]]) {
				value = @"";
				[queryString appendFormat:@"%@=%@&", key, [self urlEncode:value]];
			} else if ([unknownTypeValue isKindOfClass:[NSArray class]]) {
				NSArray *valueArray = (NSArray*)unknownTypeValue;
				NSString *modifiedKey = [key stringByAppendingString:@"[]"];
				
				if (valueArray.count == 0) [queryString appendFormat:@"%@=&", modifiedKey]; // send an empty array
				
				for (NSString *value in valueArray) {
					[queryString appendFormat:@"%@=%@&", modifiedKey, [self urlEncode:value]];
				}
				
			} else {
				value = [unknownTypeValue description];
				[queryString appendFormat:@"%@=%@&", key, [self urlEncode:value]];
			}
		}
		
		if ([queryString hasSuffix:@"&"]) {
			[queryString deleteCharactersInRange:NSMakeRange(queryString.length - 1, 1)];
		}
		
		if ([self.method isEqualToString:@"GET"] || [self.method isEqualToString:@"DELETE"] ) {
			request.URL = [NSURL URLWithString:[NSString stringWithFormat:@"%@?%@", url.absoluteString, queryString]];
		} else if ([self.method isEqualToString:@"POST"] || [self.method isEqualToString:@"PUT"]) {
			NSData *queryData = [NSData dataWithBytes: [queryString UTF8String] length:queryString.length];
			[request setValue:@"application/x-www-form-urlencoded; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
			[request setHTTPBody: queryData];
		}
	} else if (bodyData) {
		[request setHTTPBody: bodyData];
	}
		
	self.urlConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
	[self.urlConnection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
	
	if (!self.disableBackgroundDownload) { // start background task unless disabled
		self.backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
			[self cancelDownload];
			if (self.errorBlock) self.errorBlock(self, [NSError errorWithDomain:@"KSDataDownloader" code:KSDataDownloaderBackgroundTaskNoTimeLeftErrorCode userInfo:@{NSLocalizedDescriptionKey: @"backround task has no time left"}]);
			[[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskIdentifier];
			self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
		}];
	}
	
	[self.urlConnection start];
}

- (void)startRequest:(NSURL *)url httpBodyData:(NSData*)httpBodyData {
	[self startRequest:url parameters:nil httpBodyData:httpBodyData];
}

- (void)startRequest:(NSURL *)url parameters:(NSDictionary*)parameters {
	[self startRequest:url parameters:parameters httpBodyData:nil];
}

- (void)startRequest:(NSURL *)url {
	[self startRequest:url parameters:nil httpBodyData:nil];
}

- (NSData*)downloadedData {
	return [self.activeDownloadData copy];
}

#pragma mark - Credentials
- (void)setUsername:(NSString*)username andPassword:(NSString*)password {
	NSURLCredential *credential = [NSURLCredential credentialWithUser:username password:password persistence:NSURLCredentialPersistenceNone];
	self.credential = credential;
}

#pragma mark - Headers
- (void)setHeader:(NSString*)value forKey:(NSString*)key {
	if (value != nil) {
		self.headers[key] = value;
	} else {
		[self removeHeaderForKey:key];
	}
}

- (void)removeHeaderForKey:(NSString*)key {
	if (key != nil) [self.headers removeObjectForKey:key];
}

+ (void)setGlobalHeader:(NSString*)value forKey:(NSString*)key {
	if (value != nil) {
		globalHeaders[key] = value;
	} else {
		[self removeGlobalHeaderForKey:key];
	}
}

+ (void)removeGlobalHeaderForKey:(NSString*)key {
	if (key != nil) [globalHeaders removeObjectForKey:key];
}

#pragma mark - NetworkActivityIndicatorManager
+ (void)setUseNetworkActivityIndicatorManager:(BOOL)showIndicator {
	useNetworkActivityIndicatorManager = showIndicator;
}

#pragma mark - NSURLConnectionDelegate
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSHTTPURLResponse *)response {
	self.contentLength = [response.allHeaderFields[@"Content-Length"] longLongValue];
	if (self.progressBlock != nil && self.contentLength > 0) {
		self.progressBlock(self, 0.15f);
	}
	if (self.uploadProgressBlock) self.uploadProgressBlock(self, 0.0f);
	self.urlResponse = response;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    if (connection == self.urlConnection) {
		if (self.outputStream) { // file download
			self.outputStreamBytesWritten += [self.outputStream write:data.bytes maxLength:data.length];
		} else { // download to memory
			[self.activeDownloadData appendData:data];
		}
		if (self.progressBlock != nil && self.contentLength > 0) {
			float progress;
			
			if (self.outputStream)
				progress = 0.15f + 0.85 * ((double)self.outputStreamBytesWritten / (double)self.contentLength);
			else
				progress = 0.15f + 0.85 * ((double)self.activeDownloadData.length / (double)self.contentLength);
			
			self.progressBlock(self, progress);
		}
	}
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	if (!self.operationEnded) {
		self.operationEnded = YES;
		if (useNetworkActivityIndicatorManager) [[KSNetworkActivityIndicatorManager sharedManager] decrease];
	}

	self.errorBlock(self, error);
	self.activeDownloadData = nil;
	self.urlConnection = nil;
	self.urlResponse = nil;
	if (self.outputStream) {
		[self.outputStream close];
		[[NSFileManager defaultManager] removeItemAtURL:self.tmpFileUrl error:nil];
	}
	
	if (self.backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
		[[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskIdentifier];
		self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
	}
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	if (!self.operationEnded) {
		self.operationEnded = YES;
		if (useNetworkActivityIndicatorManager) [[KSNetworkActivityIndicatorManager sharedManager] decrease];
	}
	
	[self.outputStream close];
	
	if (self.urlResponse.statusCode < 400) { // let's assume everything below 400 indicates a success :-)
		if (self.jsonSuccessBlock) {
            id responseObject = self.activeDownloadData.length == 0 ? nil : [NSJSONSerialization JSONObjectWithData:self.activeDownloadData options:0 error:nil];
			self.jsonSuccessBlock(self, responseObject);
		} else if (self.successBlock) {
			NSString *stringData = nil;
			NSStringEncoding stringEncoding;
			if (self.urlResponse.textEncodingName.length > 0) {
				CFStringEncoding encoding = CFStringConvertIANACharSetNameToEncoding((__bridge CFStringRef)(self.urlResponse.textEncodingName));
				stringEncoding = CFStringConvertEncodingToNSStringEncoding(encoding);
			} else {
				stringEncoding = NSUTF8StringEncoding; // assume utf-8 if the server sends no header
			}
			
            stringData = self.activeDownloadData == nil ? @"" : [[NSString alloc] initWithData:self.activeDownloadData encoding:stringEncoding];
			
			self.successBlock(self, self.activeDownloadData, stringData);
		} else if (self.fileSuccessBlock) {
			NSError *error;
			
			// make sure there is nothing in the way
			[[NSFileManager defaultManager] removeItemAtURL:self.targetFileUrl error:&error];
			
			// move the file to the target url
			BOOL success = [[NSFileManager defaultManager] moveItemAtURL:self.tmpFileUrl toURL:self.targetFileUrl error:&error];
			if (!success) {
				if (self.errorBlock) self.errorBlock(self, error);
			} else {
				self.fileSuccessBlock(self);
			}
		}
	} else {
		NSError *error = [NSError errorWithDomain:@"KSDataDownloader" code:self.urlResponse.statusCode userInfo:@{NSLocalizedDescriptionKey: @"Invalid HTTP Reponse Code"}];
		if (self.errorBlock) self.errorBlock(self, error);
	}
	
	self.activeDownloadData = nil;
	self.urlConnection = nil;
	self.urlResponse = nil;
	if (self.backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
		[[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskIdentifier];
		self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
	}
}

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
	// return YES for HTTP Basic Authentication, we don't support anything else
	return self.credential && [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodHTTPBasic];
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
	// authenticate with http basic
	[challenge.sender useCredential:self.credential forAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite {
	if (totalBytesExpectedToWrite != 0) {
		float progress = (float)totalBytesWritten / (float)totalBytesExpectedToWrite;
		if (self.uploadProgressBlock) self.uploadProgressBlock(self, progress);
	}
}

#pragma mark - Utility
- (NSString*)urlEncode:(NSString*)input {
	NSString *encodedString = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL,(CFStringRef)input,NULL,(CFStringRef)@"!*'();:@&=+$,/?%#[]",kCFStringEncodingUTF8 ));
	return encodedString;
}
@end
