import Foundation

public class CompoundRequest: Request {
    private(set) var ignoreErrors = false

    @discardableResult
    public func add(_ request: HttpRequest) -> Self {
        // empty implementation, for subclasses to override
        return self
    }
    
    @discardableResult
    public func allowErrors() -> Self {
        ignoreErrors = true
        return self
    }
}
