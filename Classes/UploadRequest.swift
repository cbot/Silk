import Foundation

public class UploadRequest: HttpRequest {
    private var task: URLSessionUploadTask?
    private var uploadFileUrl: URL?
    private var tmpFileUrl: URL? {
        get {
            return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("upload-\(tag)")
        }
    }

    // MARK: - Public Methods
    public func uploadFileUrl(_ url: URL) -> Self {
        uploadFileUrl = url
        return self
    }
    
    // MARK: - Overridden methods
    public override func cancel() {
        super.cancel()
        if let task = task {
            task.cancel()
            clearTmpFile()
            NotificationCenter.default.post(name: Notification.Name(rawValue: "SilkRequestEnded"), object: nil)
        }
    }
    
    public override func execute() -> Bool {
        if !(super.execute()) {
            return false
        }
        
        if let uploadFileUrl = uploadFileUrl, FileManager.default.fileExists(atPath: uploadFileUrl.path) {
            task = manager.backgroundSession.uploadTask(with: request as URLRequest, fromFile: uploadFileUrl)
        } else if let bodyData = request.httpBody {
            if let tmpFileUrl = tmpFileUrl {
                if (try? bodyData.write(to: tmpFileUrl, options: [.atomic])) != nil {
                    task = manager.backgroundSession.uploadTask(with: request as URLRequest, fromFile: tmpFileUrl)
                } else {
                    print("[Silk] unable to write tmp upload file")
                }
            }
        } else {
            print("[Silk] unable to execute request - no data to upload")
            return false
        }
        
        if let task = task {
            task.taskDescription = tag
            manager.registerRequest(self)
            task.resume()
            NotificationCenter.default.post(name: Notification.Name(rawValue: "SilkRequestStarted"), object: nil)
            return true
        } else {
            return false
        }
    }
    
    override func handleResponse(_ response: HTTPURLResponse, error: NSError?, task: URLSessionTask) {
        super.handleResponse(response, error: error, task: task)
        clearTmpFile()
    }
    
    // MARK: - Private Methods
    private func clearTmpFile() {
        if let tmpFileUrl = tmpFileUrl, FileManager.default.fileExists(atPath: tmpFileUrl.path) {
            do {
                try FileManager.default.removeItem(at: tmpFileUrl)
            } catch {}
        }
    }
}
