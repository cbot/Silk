import Foundation

public class ParallelRequest: CompoundRequest {
    private var requests = [HttpRequest]()
    
    @discardableResult
    public override func add(_ request: HttpRequest) -> Self {
        super.add(request)
        requests.append(request)
        return self
    }
    
    private func remove(_ request: HttpRequest, error: NSError? = nil, body: String? = nil, data: Data? = nil, response: HTTPURLResponse? = nil) {
        if let index = requests.index(of: request) {
            requests.remove(at: index)
        }
        
        if let error = error, !ignoreErrors {
            for request in requests {
                request.cancel()
            }
            errorClosure?(error, body ?? "", data ?? Data(), response, self)
            manager.unregisterRequest(self)
            requests.removeAll(keepingCapacity: false)
        } else {
            if requests.isEmpty {
                successClosure?("", Data(), URLResponse(), self)
                manager.unregisterRequest(self)
            }
        }
    }
    
    @discardableResult
    public override func execute() -> Bool {
        if !super.execute() {
            return false
        }
        
        var started = false
        for request in requests {
            let originalSuccessClosure = request.successClosure
            let originalErrorClosure = request.errorClosure
            
            request.completion({ [weak self] body, data, response, context in
                if let weakSelf = self {
                    originalSuccessClosure?(body, data, response, weakSelf)
                    weakSelf.remove(request)
                }
            }, error: { [weak self] error, body, data, response, context in
                if let weakSelf = self {
                    originalErrorClosure?(error, body, data, response, weakSelf)
                    weakSelf.remove(request, error: error, body: body, data:data, response: response as? HTTPURLResponse)
                }
            })
            
            started = request.execute() || started
        }
        
        if started {
            manager.registerRequest(self)
        }
        return started
    }
    
    public override func cancel() {
        for request in requests {
            request.cancel()
        }
        requests.removeAll(keepingCapacity: false)
        super.cancel()
    }
}
