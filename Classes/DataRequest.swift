import Foundation

public class DataRequest: HttpRequest {
    private var task: URLSessionDataTask?
    
    // MARK: - Public Methods
    @discardableResult
    public func formUrlEncoded(_ data: Dictionary<String, Any?>) -> Self {
        let requiresMultipart = data.values.contains { $0 is SilkMultipartObject }
        
        if requiresMultipart {
            var bodyData = Data()
            let boundary = "----SilkFormBoundary\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            // support ordered parts
            let sortedData = data.sorted(by: { lhs, rhs in
                if let lhs = lhs.value as? SilkMultipartObject, let rhs = rhs.value as? SilkMultipartObject {
                    return lhs.index < rhs.index
                } else if lhs is SilkMultipartObject {
                    return true
                } else {
                    return false
                }
            })
            
            for (key, value) in sortedData {
                if let valueNumber = value as? NSNumber {
                    bodyData.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(key)\"\r\n".data(using: String.Encoding.ascii) ?? Data())
                    bodyData.append("\r\n\(valueNumber.stringValue)\r\n".data(using: String.Encoding.ascii) ?? Data())
                } else if let valueString = value as? String {
                    bodyData.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(key)\"\r\n".data(using: String.Encoding.ascii) ?? Data())
                    bodyData.append("\r\n\(valueString)\r\n".data(using: String.Encoding.ascii) ?? Data())
                } else if let valueObject = value as? SilkMultipartObject {
                    var bodyString = "--\(boundary)\r\n"
                    bodyString.append("Content-Disposition: form-data; name=\"\(key)\"")
            
                    if let fileName = valueObject.fileName {
                        bodyString.append("; filename=\"\(fileName)\"")
                    }
                    
                    bodyString.append("\r\n")
                    bodyString.append("Content-Type: \(valueObject.contentType)\r\n\r\n")
                    
                    bodyData.append(bodyString.data(using: String.Encoding.ascii) ?? Data())
                    bodyData.append(valueObject.data as Data)
                    bodyData.append("\r\n".data(using: String.Encoding.ascii) ?? Data())
                }
            }
            
            bodyData.append("--\(boundary)--\r\n".data(using: String.Encoding.ascii) ?? Data())
            body(bodyData as Data)
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
            
            body(bodyString, encoding: String.Encoding.ascii)
        }
        
        return self
    }
    
    @discardableResult
    public func formJson(_ input: Dictionary<String, Any?>) -> Self {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var data = input
        
        for (key, value) in data {
            if value == nil {
                data[key] = NSNull()
            } else if value is SilkMultipartObject {
                print("SilkMultipartObjects are not supported via formJson - skipping")
                data.removeValue(forKey: key)
            }
        }
        
        do {
            let bodyData = try JSONSerialization.data(withJSONObject: data, options: [])
            body(bodyData)
        } catch {
            print("[Silk] unable to encode body data")
        }
        
        return self
    }
    
    @discardableResult
    public func formJson(_ data: Array<Any?>) -> Self {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let data = try JSONSerialization.data(withJSONObject: data, options: [])
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
            NotificationCenter.default.post(name: Notification.Name(rawValue: "SilkRequestEnded"), object: nil)
        }
    }
    
    @discardableResult
    public override func execute() -> Bool {
        if !(super.execute()) {
            return false
        }
        
        task = manager.ordinarySession.dataTask(with: request as URLRequest)
        if let task = task {
            task.taskDescription = tag
            manager.registerRequest(self)
            
            if manager.useActivityManager {
                manager.activityManager.increase()
            }
            
            task.resume()
            NotificationCenter.default.post(name: Notification.Name(rawValue: "SilkRequestStarted"), object: nil)
            return true
        } else {
            return false
        }
    }
}
