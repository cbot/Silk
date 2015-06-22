import Foundation

public class HttpRequest: Request {
    let request = NSMutableURLRequest()
    
    private(set) var uploadProgressClosure: ((progress: Float, bytesSent: Int64, totalBytes: Int64) -> Void)?
    private(set) var responseData = NSMutableData()
    private(set) var credentials: NSURLCredential?
        
    public func url(url: NSURL?) -> Self {
        if let url = url {
            request.URL = url
        }
        return self
    }
    
    public func url(url: String?) -> Self {
        if let url = url?.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding) {
            request.URL = NSURL(string: url)
        }
        return self
    }
    
    public func credentials(credentials: NSURLCredential?, sendPrecautionary: Bool = true) -> Self {
        self.credentials = credentials
        
        if sendPrecautionary {
            if let credentials = credentials, user = credentials.user, password = credentials.password {
                let userPasswordString = "\(user):\(password)"
                let userPasswordData = userPasswordString.dataUsingEncoding(NSUTF8StringEncoding)
                let base64EncodedCredential = userPasswordData!.base64EncodedStringWithOptions(nil)
                let authString = "Basic \(base64EncodedCredential)"
                request.setValue(authString, forHTTPHeaderField: "Authorization")
            }
        }
        
        return self
    }
    
    public func uploadProgress(progressClosure progress: ((progress: Float, bytesSent: Int64, totalBytes: Int64) -> Void)?) -> Self {
        uploadProgressClosure = progress
        return self
    }
    
    public func timeout(interval: NSTimeInterval) -> Self {
        request.timeoutInterval = interval
        return self
    }
    
    public func cachePolicy(policy: NSURLRequestCachePolicy) -> Self {
        request.cachePolicy = policy
        return self
    }
    
    public func body(body: NSData) -> Self {
        request.HTTPBody = body
        return self
    }
    
    public func body(body: String, encoding: NSStringEncoding) -> Self {
        if let bodyData = body.dataUsingEncoding(encoding, allowLossyConversion: false) {
            request.HTTPBody = bodyData
        } else {
            println("[Silk] unable to encode body data")
        }
        return self
    }
    
    public func method(method: String) -> Self {
        request.HTTPMethod = method
        return self
    }
    
    public func header(headerName: String, value: String) -> Self {
        request.setValue(value, forHTTPHeaderField: headerName)
        return self
    }
    
    public func headers(headers: [String: String]) -> Self {
        for (headerName, value) in headers {
            request.setValue(value, forHTTPHeaderField: headerName)
        }
        return self
    }
    
    public func contentType(type: String) -> Self {
        return header("Content-Type", value: type)
    }
    
    public func get() {
        method("GET")
        execute()
    }
    
    public func post() {
        method("POST")
        execute()
    }
    
    public func put() {
        method("PUT")
        execute()
    }
    
    public func delete() {
        method("DELETE")
        execute()
    }
    
    public func patch() {
        method("PATCH")
        execute()
    }
    
    override public func execute() -> Bool {
        if request.URL == nil {
            println("[Silk] unable to execute request - url is nil!")
            return false
        }
        
        return super.execute()
    }
    
    override func appendResponseData(data: NSData, task: NSURLSessionTask) {
        responseData.appendData(data)
    }
    
    override func handleResponse(response: NSHTTPURLResponse, error: NSError?, task: NSURLSessionTask) {
        manager.unregisterRequest(self)
        
        if let error = error where error.code == -999 { // cancelled request
            return
        }
        
        var stringEncoding : NSStringEncoding = NSUTF8StringEncoding // default
        if let encodingName = response.textEncodingName {
            if count(encodingName) > 0 {
                let encoding = CFStringConvertIANACharSetNameToEncoding(encodingName)
                stringEncoding = CFStringConvertEncodingToNSStringEncoding(encoding)
            }
        }
        
        let body = NSString(data: responseData, encoding: stringEncoding)
        
        if let error = error {
            if let errorClosure = errorClosure {
                dispatch_async(dispatch_get_main_queue()) {
                    errorClosure(error: error, body: (body as? String ?? ""), data: self.responseData, response: response, request: self)
                }
            }
        } else {
            if response.statusCode < 200 || response.statusCode >= 300 {
                if let errorClosure = self.errorClosure {
                    let customError = NSError(domain: "Silk", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: "Status Code \(response.statusCode)"])
                    dispatch_async(dispatch_get_main_queue()) {
                        errorClosure(error: customError, body: (body as? String ?? ""), data: self.responseData, response: response, request: self)
                    }
                }
            } else {
                if let successClosure = self.successClosure {
                    dispatch_async(dispatch_get_main_queue()) {
                        successClosure(body: (body as? String ?? ""), data: self.responseData, response: response, request: self)
                    }
                }
            }
        }
    }
}