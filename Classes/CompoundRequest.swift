import Foundation

public class CompoundRequest: Request {
    private(set) var ignoreErrors = false

    public func add(request: HttpRequest) -> Self {
        // empty implementation, for subclasses to override
        return self
    }
    
    public func allowErrors() -> Self {
        ignoreErrors = true
        return self
    }
}