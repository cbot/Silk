import Foundation

public class DataRequest: HttpRequest {
    private var task: NSURLSessionDataTask?
    
    // MARK: - Public Methods
    public func formUrlEncoded(data: Dictionary<String, AnyObject>) -> Self {

        let requiresMultipart = data.values.contains { $0 is SilkMultipartObject }
        if requiresMultipart {
            let bodyData = NSMutableData()
            let boundary = "----SilkFormBoundary\(NSUUID().UUIDString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            for (key, value) in data {
                if let valueNumber = value as? NSNumber {
                    bodyData.appendData("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(key)\"\r\n".dataUsingEncoding(NSASCIIStringEncoding) ?? NSData())
                    bodyData.appendData("\r\n\(valueNumber.stringValue)\r\n".dataUsingEncoding(NSASCIIStringEncoding) ?? NSData())
                } else if let valueString = value as? String {
                    bodyData.appendData("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(key)\"\r\n".dataUsingEncoding(NSASCIIStringEncoding) ?? NSData())
                    bodyData.appendData("\r\n\(valueString)\r\n".dataUsingEncoding(NSASCIIStringEncoding) ?? NSData())
                } else if let valueObject = value as? SilkMultipartObject {
                    bodyData.appendData("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(key)\"; filename=\"\(valueObject.fileName ?? "file")\"\r\nContent-Type: \(valueObject.contentType)\r\n\r\n".dataUsingEncoding(NSASCIIStringEncoding) ?? NSData())
                    bodyData.appendData(valueObject.data)
                    bodyData.appendData("\r\n".dataUsingEncoding(NSASCIIStringEncoding) ?? NSData())
                }
            }
            
            bodyData.appendData("--\(boundary)--\r\n".dataUsingEncoding(NSASCIIStringEncoding) ?? NSData())
            body(bodyData)
        } else {
            var bodyString = ""
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            
            for (key, value) in data {
                if (!bodyString.isEmpty) {
                    bodyString += "&"
                }
                
                var convertedString = ""
                if let valueNumber = value as? NSNumber {
                    convertedString = "\(valueNumber.stringValue)"
                } else if let valueString = value as? String {
                    convertedString = valueString
                }
                
                bodyString += key + "=" + manager.urlEncode(convertedString)
            }
            
            body(bodyString, encoding: NSASCIIStringEncoding)
        }
        
        return self
    }
    
    
    public func formJson(input: Dictionary<String, AnyObject?>) -> Self {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var data = input
        
        for (key, value) in data {
            if value == nil {
                data[key] = NSNull()
            } else if value is SilkMultipartObject {
                print("SilkMultipartObjects are not supported via formJson - skipping")
                data.removeValueForKey(key)
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
        } catch {
            print("[Silk] unable to encode body data")
        }
        
        return self
    }
    
    // MARK: - Overridden methods
    public override func cancel() {
        super.cancel()
        if let task = task {
            task.cancel()
            NSNotificationCenter.defaultCenter().postNotificationName("SilkRequestEnded", object: nil)
        }
    }
    
    public override func execute() -> Bool {
        if !(super.execute()) {
            return false
        }
        
        task = manager.ordinarySession.dataTaskWithRequest(request as NSURLRequest)
        if let task = task {
            task.taskDescription = tag
            manager.registerRequest(self)
            task.resume()
            NSNotificationCenter.defaultCenter().postNotificationName("SilkRequestStarted", object: nil)
            return true
        } else {
            return false
        }
    }
}