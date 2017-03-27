import UIKit

public class SilkActivityManager {
    private let internalQueue = DispatchQueue(label: "SilkActivityManager")
    
    public var activityClosure: (_ isActive: Bool) -> () = { isActive in
        UIApplication.shared.isNetworkActivityIndicatorVisible = isActive
    }
    
    private var counter = 0 {
        didSet {
            if counter < 0 { counter = 0 }
            DispatchQueue.main.sync {
                activityClosure(counter > 0)
            }
        }
    }
    
    internal init() {}
    
    public func increase() {
        internalQueue.async {
            self.counter += 1
        }
    }
    
    public func decrease() {
        internalQueue.async {
            self.counter -= 1
        }
    }
    
    public func reset() {
        internalQueue.async {
            self.counter = 0
        }
    }
}
