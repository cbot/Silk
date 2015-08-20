import Foundation

public class Request: Equatable {
    public typealias SuccessClosure = ((body: String, data: NSData, response: NSURLResponse, request: Request)->())?
    public typealias ErrorClosure = ((error: NSError, body: String, data: NSData, response: NSURLResponse?, request: Request)->())?
    
    var manager: SilkManager
    internal(set) var successClosure: SuccessClosure
    internal(set) var errorClosure: ErrorClosure
    private(set) var tag: String = NSUUID().UUIDString
    private(set) var group = "Requests"
    public var compoundContext = [String: AnyObject]()
    
    func context(context: [String: AnyObject]) -> Self {
        compoundContext = context
        return self
    }
    
    init(manager: SilkManager) {
        self.manager = manager
    }
    
    public func tag(requestTag: String) -> Self {
        tag = requestTag
        return self
    }
    
    public func group(requestGroup: String) -> Self {
        group = requestGroup
        return self
    }
    
    public func completion(success: SuccessClosure, error: ErrorClosure) -> Self {
        successClosure = success
        errorClosure = error
        return self
    }
    
    public func execute() -> Bool {
        // empty implementation, for subclasses to override
        return true
    }
    
    public func cancel() {
        manager.unregisterRequest(self)
        // empty implementation, for subclasses to override
    }
    
    func appendResponseData(data: NSData, task: NSURLSessionTask) {
        // empty implementation, for subclasses to override
    }
    
    func handleResponse(response: NSHTTPURLResponse, error: NSError?, task: NSURLSessionTask) {
        // empty implementation, for subclasses to override
    }
}

// MARK: - Equatable
public func ==(lhs: Request, rhs: Request) -> Bool {
    return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
}