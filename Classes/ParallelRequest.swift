import Foundation

public class ParallelRequest: CompoundRequest {
    private var requests = [HttpRequest]()
    
    override public func add(request: HttpRequest) -> Self {
        super.add(request)
        requests.append(request)
        return self
    }
    
    private func remove(request: HttpRequest, error: NSError? = nil, body: String? = nil, data: NSData? = nil, response: NSHTTPURLResponse? = nil) {
        if let index = find(requests, request) {
            requests.removeAtIndex(index)
        }
        
        if let error = error where !ignoreErrors {
            for request in requests {
                request.cancel()
            }
            errorClosure?(error: error, body: body ?? "", data: data ?? NSData(), response: response, request: self)
            manager.unregisterRequest(self)
            requests.removeAll(keepCapacity: false)
        } else {
            if requests.isEmpty {
                successClosure?(body: "", data: NSData(), response: NSURLResponse(), request: self)
                manager.unregisterRequest(self)
            }
        }
    }
    
    override public func execute() -> Bool {
        if !super.execute() {
            return false
        }
        
        var started = false
        for request in requests {
            let originalSuccessClosure = request.successClosure
            let originalErrorClosure = request.errorClosure
            
            request.completion({ [weak self] body, data, response, context in
                if let weakSelf = self {
                    originalSuccessClosure?(body: body, data: data, response: response, request: weakSelf)
                    weakSelf.remove(request)
                }
            }, error: { [weak self] error, body, data, response, context in
                if let weakSelf = self {
                    originalErrorClosure?(error: error, body: body, data: data, response: response, request: weakSelf)
                    weakSelf.remove(request, error: error, body: body, data:data, response: response as? NSHTTPURLResponse)
                }
            })
            
            started = request.execute() || started
        }
        
        if started {
            manager.registerRequest(self)
        }
        return started
    }
    
    override public func cancel() {
        for request in requests {
            request.cancel()
        }
        requests.removeAll(keepCapacity: false)
        super.cancel()
    }
}