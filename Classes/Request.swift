import Foundation

public class Request: Equatable {
    public typealias SuccessClosure = ((body: String, data: Data, response: URLResponse, request: Request)->())?
    public typealias ErrorClosure = ((error: NSError, body: String, data: Data, response: URLResponse?, request: Request)->())?
    
    var manager: SilkManager
    internal(set) var successClosure: SuccessClosure
    internal(set) var errorClosure: ErrorClosure
    private(set) var tag: String = UUID().uuidString
    private(set) var group = "Requests"
    public var compoundContext = [String: AnyObject]()
    
    func context(_ context: [String: AnyObject]) -> Self {
        compoundContext = context
        return self
    }
    
    init(manager: SilkManager) {
        self.manager = manager
    }
    
    @discardableResult
    public func tag(_ requestTag: String) -> Self {
        tag = requestTag
        return self
    }
    
    @discardableResult
    public func group(_ requestGroup: String) -> Self {
        group = requestGroup
        return self
    }
    
    @discardableResult
    public func completion(_ success: SuccessClosure, error: ErrorClosure) -> Self {
        successClosure = success
        errorClosure = error
        return self
    }
    
    @discardableResult
    public func execute() -> Bool {
        // empty implementation, for subclasses to override
        return true
    }
    
    public func cancel() {
        manager.unregisterRequest(self)
        // empty implementation, for subclasses to override
    }
    
    func appendResponseData(_ data: Data, task: URLSessionTask) {
        // empty implementation, for subclasses to override
    }
    
    func handleResponse(_ response: HTTPURLResponse, error: NSError?, task: URLSessionTask) {
        // empty implementation, for subclasses to override
    }
}

// MARK: - Equatable
public func ==(lhs: Request, rhs: Request) -> Bool {
    return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
}
