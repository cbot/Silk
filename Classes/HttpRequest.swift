import Foundation

public class HttpRequest: Request {
    let request = NSMutableURLRequest()
    
    private(set) var uploadProgressClosure: ((_ progress: Float, _ bytesSent: Int64, _ totalBytes: Int64) -> Void)?
    private(set) var responseData = Data()
    private(set) var credentials: URLCredential?
    private(set) var trustsAllCertificates = false
    private(set) var trustedCertificates = [Data]()
    private(set) var publicKeyPinningRequired = false
    
    @discardableResult
    public func url(_ url: URL?) -> Self {
        if let url = url {
            request.url = url
            configureGlobalHeadersAndCredentials()
        }
        return self
    }
    
    @discardableResult
    public func url(_ url: String?) -> Self {
        if let url = url {
            request.url = URL(string: url)
            configureGlobalHeadersAndCredentials()
        }
        return self
    }
    
    @discardableResult
    public func credentials(_ credentials: URLCredential?, sendPrecautionary: Bool = true) -> Self {
        self.credentials = credentials
        
        if sendPrecautionary {
            if let credentials = credentials, let user = credentials.user, let password = credentials.password {
                let userPasswordString = "\(user):\(password)"
                let userPasswordData = userPasswordString.data(using: String.Encoding.utf8)
                let base64EncodedCredential = userPasswordData!.base64EncodedString(options: [])
                let authString = "Basic \(base64EncodedCredential)"
                request.setValue(authString, forHTTPHeaderField: "Authorization")
            }
        }
        
        return self
    }
    
    @discardableResult
    public func uploadProgress(progressClosure progress: ((_ progress: Float, _ bytesSent: Int64, _ totalBytes: Int64) -> Void)?) -> Self {
        uploadProgressClosure = progress
        return self
    }
    
    @discardableResult
    public func timeout(_ interval: TimeInterval) -> Self {
        request.timeoutInterval = interval
        return self
    }
    
    @discardableResult
    public func cachePolicy(_ policy: NSURLRequest.CachePolicy) -> Self {
        request.cachePolicy = policy
        return self
    }
    
    @discardableResult
    public func body(_ body: Data) -> Self {
        request.httpBody = body
        return self
    }
    
    @discardableResult
    public func body(_ body: String, encoding: String.Encoding) -> Self {
        if let bodyData = body.data(using: encoding, allowLossyConversion: false) {
            request.httpBody = bodyData
        } else {
            print("[Silk] unable to encode body data")
        }
        return self
    }
    
    @discardableResult
    public func method(_ method: String) -> Self {
        request.httpMethod = method
        return self
    }
    
    @discardableResult
    public func header(_ headerName: String, value: String) -> Self {
        request.setValue(value, forHTTPHeaderField: headerName)
        return self
    }
    
    @discardableResult
    public func headers(_ headers: [String: String]) -> Self {
        for (headerName, value) in headers {
            request.setValue(value, forHTTPHeaderField: headerName)
        }
        return self
    }
    
    @discardableResult
    public func contentType(_ type: String) -> Self {
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
    
    public func head() {
        method("HEAD")
        execute()
    }
    
    @discardableResult
    public override func execute() -> Bool {
        if request.url == nil {
            print("[Silk] unable to execute request - url is nil!")
            return false
        }
        
        return super.execute()
    }
    
    override func appendResponseData(_ data: Data, task: URLSessionTask) {
        responseData.append(data)
    }
    
    override func handleResponse(_ response: HTTPURLResponse, error: NSError?, task: URLSessionTask) {
        manager.unregisterRequest(self)
        
        if let error = error, error.code == -999 { // cancelled request
            return
        }
        
        var stringEncoding: String.Encoding = String.Encoding.utf8 // default
        if let encodingName = response.textEncodingName {
            if encodingName.characters.count > 0 {
                let encoding = CFStringConvertIANACharSetNameToEncoding(encodingName as CFString!)
                stringEncoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(encoding))
            }
        }
        
        let body = NSString(data: responseData as Data, encoding: stringEncoding.rawValue)
        
        if let error = error {
            if let errorClosure = errorClosure {
                DispatchQueue.main.async {
                    errorClosure(error, (body as? String ?? ""), self.responseData, response, self)
                }
            }
        } else {
            if response.statusCode < 200 || response.statusCode >= 300 {
                if let errorClosure = self.errorClosure {
                    let customError = NSError(domain: "Silk", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: "Status Code \(response.statusCode)"])
                    DispatchQueue.main.async {
                        errorClosure(customError, (body as? String ?? ""), self.responseData, response, self)
                    }
                }
            } else {
                if let successClosure = self.successClosure {
                    DispatchQueue.main.async {
                        successClosure((body as? String ?? ""), self.responseData, response, self)
                    }
                }
            }
        }
    }
    
    /**
    Adds a certificate to the list of trusted certificates. Use this for self signed certificates. If you want Silk to only trust certficates added using this method (certificate pinning), call the requirePublicKeyPinning method.
    
    - parameter certificateData: the data of the certificate to be trusted
    */
    @discardableResult
    public func trustCertificate(_ certificateData: Data?) -> Self {
        if let certificateData = certificateData {
            trustedCertificates.append(certificateData)
        }
        return self
    }
    
    /**
    Calling this method forces Silk to only trust certificates added using the trustCertificate(certificateData:) method (certificate pininng).
    */
    @discardableResult
    public func requirePublicKeyPinning() -> Self {
        publicKeyPinningRequired = true
        return self
    }
    
    /**
    Trusts all TLS certificates. You should only use this setting during development!
    */
    @discardableResult
    public func trustAllCertificates() -> Self {
        print("Silk: WARNING! certificate validation is disabled!")
        trustsAllCertificates = true
        return self
    }
    
    // MARK: - Utility
    private func configureGlobalHeadersAndCredentials() {
        guard let host = request.url?.host else { return }
        
        headers(manager.globalHeaders.headersForHost(host))
        credentials(manager.globalCredentials.credentialsForHost(host))
    }
}
