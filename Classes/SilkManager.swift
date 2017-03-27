import Foundation

public class SilkManager: NSObject, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate {
    public class var sharedInstance: SilkManager {
        struct Singleton {
            static let instance = SilkManager()
        }
        return Singleton.instance
    }
    
    private var registeredRequests = [String: Request]()
    private var backgroundSessionCompletionHandler: (() -> Void)?
    
    var globalCredentials = SilkGlobalCredentials()
    var globalHeaders = SilkGlobalHeaders()
    
    lazy var backgroundSession : URLSession = {
        let sessionConfig = URLSessionConfiguration.background(withIdentifier: Bundle.main.bundleIdentifier!)
        sessionConfig.httpShouldUsePipelining = true
        sessionConfig.urlCache = URLCache.shared
        sessionConfig.urlCredentialStorage = URLCredentialStorage.shared
        return Foundation.URLSession(configuration: sessionConfig, delegate: self, delegateQueue: OperationQueue.main)
    }()
    
    lazy var ordinarySession : URLSession = {
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.httpShouldUsePipelining = true
        sessionConfig.urlCache = URLCache.shared
        sessionConfig.urlCredentialStorage = URLCredentialStorage.shared
        return Foundation.URLSession(configuration: sessionConfig, delegate: self, delegateQueue: OperationQueue.main)
    }()
    
    public let activityManager = SilkActivityManager()
    public var useActivityManager = false
    public var reportCancelledRequestsAsErrors = false
    
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
    public func cancelRequest(_ request: HttpRequest?) {
        request?.cancel()
    }
    
    public func cancelRequest(_ tag: String) {
        if let request = requestForTag(tag) {
            request.cancel()
        }
    }
    
    public func cancelRequestsInGroup(_ group: String) {
        for request in (registeredRequests.values.filter {request in request.group == group}) {
            request.cancel()
        }
    }
    
    public func cancelAllRequests() {
        for request in registeredRequests.values {
            request.cancel()
        }
    }
    
    /**
     Sets a global HTTP header to use for all requests.
     
     - parameter value: the header's value. Pass nil to remove the header with the given name.
     - parameter name:  the header's name
     - parameter host:  if given, the header is only set for requests to the specific host
     */
    public func setGlobalHeaderValue(_ value: String?, forHeaderWithName name: String, forHost host: String? = nil) {
        globalHeaders.setHeader(name, value: value, forHost: host)
    }
    
    /**
     Sets global HTTP auth credentials for all requests.
     
     - parameter credentials: the credentials to be used. Pass nil to remove credentials.
     - parameter host:        if given, the credentials are only set for requests to the specific host
     */
    public func setGlobalCredentials(_ credentials: URLCredential?, forHost host: String? = nil) {
        globalCredentials.setCredentials(credentials, forHost: host)
    }
    
    /**
     Sets global HTTP auth credentials for all requests.
     
     - parameter user:     the user name to be used. Pass nil to remove credentials.
     - parameter password: the password to be used. Pass nil to remove credentials.
     - parameter host:     if given, the credentials are only set for requests to the specific host
     */
    public func setGlobalCredentials(user: String?, password: String?, forHost host: String? = nil) {
        if let user = user, let password = password {
            globalCredentials.setCredentials(URLCredential(user: user, password: password, persistence: .none), forHost: host)
        } else {
            globalCredentials.setCredentials(nil, forHost: host)
        }
    }
    
    // MARK: - Background Sessions
    public func setBackgroundSessionCompletionHandler(_ completionHandler: @escaping (() -> ()), sessionIdentifier: String) {
        if backgroundSession.configuration.identifier == sessionIdentifier {
            backgroundSessionCompletionHandler = completionHandler
        }
    }
    
    // MARK: - Request tracking
    func registerRequest(_ request: Request) {
        registeredRequests[request.tag] = request
    }
    
    func unregisterRequest(_ request: Request) {
        registeredRequests[request.tag] = nil
    }
    
    // MARK: - NSURLSessionDelegate
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        backgroundSessionCompletionHandler?()
        backgroundSessionCompletionHandler = nil
    }
    
    // MARK: - NSURLSessionDataDelegate
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if let request = requestForTag(dataTask.taskDescription) {
            request.appendResponseData(data, task: dataTask)
        }
    }
    
    // MARK: - NSURLSessionTaskDelegate    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: "SilkRequestEnded"), object: nil)
        
        if let _ = task as? URLSessionDataTask, useActivityManager {
            activityManager.decrease()
        }
        
        // only connection errors are handled here!
        if let request = requestForTag(task.taskDescription) {
            let response = task.response as? HTTPURLResponse ?? HTTPURLResponse()
            request.handleResponse(response, error: error as NSError?, task: task)
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        if let request = requestForTag(task.taskDescription) as? HttpRequest, let uploadProgressClosure = request.uploadProgressClosure {
            let progress = Float(totalBytesSent) / Float(totalBytesExpectedToSend)
            DispatchQueue.main.async {
                uploadProgressClosure(progress, totalBytesSent, totalBytesExpectedToSend)
            }
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)  {
        if let request = requestForTag(task.taskDescription) as? HttpRequest {
            if let serverTrust = challenge.protectionSpace.serverTrust, challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
                if request.trustsAllCertificates {
                    completionHandler(Foundation.URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: serverTrust))
                } else if !request.trustedCertificates.isEmpty || request.publicKeyPinningRequired {
                    guard let certificate = SecTrustGetCertificateAtIndex(serverTrust, 0) else {
                        completionHandler(.performDefaultHandling, nil)
                        return
                    }
                    
                    for trustedCertificateData in request.trustedCertificates {
                        let certificateData = SecCertificateCopyData(certificate)
                        if trustedCertificateData == certificateData as Data {
                            completionHandler(Foundation.URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: serverTrust))
                            return
                        }
                    }
                    
                    if request.publicKeyPinningRequired {
                        completionHandler(.rejectProtectionSpace, nil)
                    } else {
                        completionHandler(.performDefaultHandling, nil)
                    }
                } else {
                    completionHandler(.performDefaultHandling, nil)
                }
            } else if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic || challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPDigest {
                if let credentials = request.credentials {
                    if let currentRequest = task.currentRequest, currentRequest.value(forHTTPHeaderField: "Authorization") == nil {
                        completionHandler(.useCredential, credentials)
                    } else {
                        completionHandler(.performDefaultHandling, nil)
                    }
                } else {
                    completionHandler(.performDefaultHandling, nil)
                }
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
    
    // MARK: - Utility
    private func requestForTag(_ tag: String?) -> Request? {
        if let tag = tag {
            return registeredRequests[tag]
        } else {
            return nil
        }
    }
    
    func urlEncode(_ input: String) -> String {
        var s = CharacterSet.urlQueryAllowed
        s.remove(charactersIn: "+&")
        return input.addingPercentEncoding(withAllowedCharacters: s) ?? ""
    }
}
