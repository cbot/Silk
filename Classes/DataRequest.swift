import Foundation

public class DataRequest: HttpRequest {
    private var task: NSURLSessionDataTask?
    
    // MARK: - Public Methods
    public func formUrlEncoded(data: Dictionary<String, AnyObject>) -> Self {
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        var bodyString = ""
        for (key, value) in data {
            if (bodyString.characters.count != 0) {
                bodyString += "&"
            }
            
            var convertedString = ""
            if let valueNumber = value as? NSNumber {
                convertedString = "\(valueNumber.longLongValue)"
            } else if let valueString = value as? String {
                convertedString = valueString
            }
            
            bodyString += key + "=" + manager.urlEncode(convertedString)
        }
        
        body(bodyString, encoding: NSASCIIStringEncoding)
        
        return self
    }
    
    
    public func formJson(var data: Dictionary<String, AnyObject?>) -> Self {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        for (key, value) in data {
            if value == nil {
                data[key] = NSNull()
            }
        }
        
        if let data = data as? Dictionary<String, AnyObject> {
            do {
                let bodyData = try NSJSONSerialization.dataWithJSONObject(data, options: [])
                body(bodyData)
            } catch {
                print("[Silk] unable to encode body data")
            }
        } else {
            print("[Silk] unable to encode body data")
        }
        
        return self
    }
    
    public func formJson(data: Array<AnyObject>) -> Self {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let data = try NSJSONSerialization.dataWithJSONObject(data, options: [])
            body(data)
        } catch _ {
            print("[Silk] unable to encode body data")
        }
        
        return self
    }
    
    // MARK: - Overridden methods
    public override func cancel() {
        super.cancel()
        if let task = task {
            task.cancel()
        }
    }
    
    public override func execute() -> Bool {
        if !(super.execute()) {
            return false
        }
        
        task = manager.session.dataTaskWithRequest(request as NSURLRequest)
        if let task = task {
            task.taskDescription = tag
            manager.registerRequest(self)
            task.resume()
            return true
        } else {
            return false
        }
    }
}