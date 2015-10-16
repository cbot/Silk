import Foundation

public class SilkManager: NSObject, NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate {
    public class var sharedInstance: SilkManager {
        struct Singleton {
            static let instance = SilkManager()
        }
        return Singleton.instance
    }
    
    private var registeredRequests = [String: Request]()
    private var backgroundSessionCompletionHandler: (() -> Void)?
    
    lazy var backgroundSession : NSURLSession = {
        let sessionConfig = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier(NSBundle.mainBundle().bundleIdentifier!)
        sessionConfig.HTTPShouldUsePipelining = true
        sessionConfig.URLCache = NSURLCache.sharedURLCache()
        sessionConfig.URLCredentialStorage = NSURLCredentialStorage.sharedCredentialStorage()
        return NSURLSession(configuration: sessionConfig, delegate: self, delegateQueue: NSOperationQueue.mainQueue())
    }()
    
    lazy var ordinarySession : NSURLSession = {
        let sessionConfig = NSURLSessionConfiguration.defaultSessionConfiguration()
        sessionConfig.HTTPShouldUsePipelining = true
        sessionConfig.URLCache = NSURLCache.sharedURLCache()
        sessionConfig.URLCredentialStorage = NSURLCredentialStorage.sharedCredentialStorage()
        return NSURLSession(configuration: sessionConfig, delegate: self, delegateQueue: NSOperationQueue.mainQueue())
    }()
    
    // MARK: - Public Methods
    public func request() -> DataRequest {
        return DataRequest(manager: self)
    }
    
    public func uploadRequest() -> UploadRequest {
        return UploadRequest(manager: self)
    }
    
    public func parallelRequest() -> ParallelRequest {
        return ParallelRequest(manager: self)
    }
    
    public func chainedRequest() -> ChainedRequest {
        return ChainedRequest(manager: self)
    }
        
    // MARK: -
    public func cancelRequest(request: HttpRequest?) {
        request?.cancel()
    }
    
    public func cancelRequest(tag: String) {
        if let request = requestForTag(tag) {
            request.cancel()
        }
    }
    
    public func cancelRequestsInGroup(group: String) {
        for request in (registeredRequests.values.filter {request in request.group == group}) {
            request.cancel()
        }
    }
    
    public func cancelAllRequests() {
        for request in registeredRequests.values {
            request.cancel()
        }
    }
    
    // MARK: - Background Sessions
    public func setBackgroundSessionCompletionHandler(completionHandler: () -> Void, sessionIdentifier: String) {
        if backgroundSession.configuration.identifier == sessionIdentifier {
            backgroundSessionCompletionHandler = completionHandler
        }
    }
    
    // MARK: - Request tracking
    func registerRequest(request: Request) {
        registeredRequests[request.tag] = request
    }
    
    func unregisterRequest(request: Request) {
        registeredRequests[request.tag] = nil
    }
    
    // MARK: - NSURLSessionDelegate
    public func URLSessionDidFinishEventsForBackgroundURLSession(session: NSURLSession) {
        backgroundSessionCompletionHandler?()
        backgroundSessionCompletionHandler = nil
    }
    
    // MARK: - NSURLSessionDataDelegate
    public func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveData data: NSData) {
        if let request = requestForTag(dataTask.taskDescription) {
            request.appendResponseData(data, task: dataTask)
        }
    }
    
    // MARK: - NSURLSessionTaskDelegate
    public func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        NSNotificationCenter.defaultCenter().postNotificationName("SilkRequestEnded", object: nil)
        
        // only connection errors are handled here!
        if let request = requestForTag(task.taskDescription) {
            let response = task.response as? NSHTTPURLResponse ?? NSHTTPURLResponse()
            request.handleResponse(response, error: error, task: task)
        }
    }
    
    public func URLSession(session: NSURLSession, task: NSURLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        if let request = requestForTag(task.taskDescription) as? HttpRequest, uploadProgressClosure = request.uploadProgressClosure {
            let progress = Float(totalBytesSent) / Float(totalBytesExpectedToSend)
            dispatch_async(dispatch_get_main_queue()) {
                uploadProgressClosure(progress: progress, bytesSent: totalBytesSent, totalBytes: totalBytesExpectedToSend)
            }
        }
    }
    
    public func URLSession(session: NSURLSession, task: NSURLSessionTask, didReceiveChallenge challenge: NSURLAuthenticationChallenge, completionHandler: (NSURLSessionAuthChallengeDisposition, NSURLCredential?) -> Void) {
        if let request = requestForTag(task.taskDescription) as? HttpRequest {
            if let serverTrust = challenge.protectionSpace.serverTrust where challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
                if request.trustsAllCertificates {
                    completionHandler(NSURLSessionAuthChallengeDisposition.UseCredential, NSURLCredential(forTrust: serverTrust))
                } else if !request.trustedCertificates.isEmpty || request.publicKeyPinningRequired {
                    guard let certificate = SecTrustGetCertificateAtIndex(serverTrust, 0) else {
                        completionHandler(.PerformDefaultHandling, nil)
                        return
                    }
                    
                    for trustedCertificateData in request.trustedCertificates {
                        let certificateData = SecCertificateCopyData(certificate)
                        if trustedCertificateData.isEqualToData(certificateData) {
                            completionHandler(NSURLSessionAuthChallengeDisposition.UseCredential, NSURLCredential(forTrust: serverTrust))
                            return
                        }
                    }
                    
                    if request.publicKeyPinningRequired {
                        completionHandler(.RejectProtectionSpace, nil)
                    } else {
                        completionHandler(.PerformDefaultHandling, nil)
                    }
                } else {
                    completionHandler(.PerformDefaultHandling, nil)
                }
            } else if let credentials = request.credentials {
                if let currentRequest = task.currentRequest where currentRequest.valueForHTTPHeaderField("Authorization") == nil {
                    completionHandler(.UseCredential, credentials)
                } else {
                    completionHandler(.PerformDefaultHandling, nil)
                }
            }
        } else {
            completionHandler(.PerformDefaultHandling, nil)
        }
    }
    
    // MARK: - Utility
    private func requestForTag(tag: String?) -> Request? {
        if let tag = tag {
            return registeredRequests[tag]
        } else {
            return nil
        }
    }
    
    func urlEncode(input: String) -> String {
        return input.stringByAddingPercentEncodingWithAllowedCharacters(.URLQueryAllowedCharacterSet())!
    }
}