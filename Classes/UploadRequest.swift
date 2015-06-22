import Foundation

public class UploadRequest: HttpRequest {
    private var task: NSURLSessionUploadTask?
    private var uploadFileUrl: NSURL?
    private var tmpFileUrl: NSURL? {
        get {
            return NSURL(fileURLWithPath: NSTemporaryDirectory()!)?.URLByAppendingPathComponent("upload-\(tag)")
        }
    }

    // MARK: - Public Methods
    public func uploadFileUrl(url: NSURL) -> Self {
        uploadFileUrl = url
        return self
    }
    
    // MARK: - Overridden methods
    public override func cancel() {
        super.cancel()
        if let task = task {
            task.cancel()
            clearTmpFile()
        }
    }
    
    public override func execute() -> Bool {
        if !(super.execute()) {
            return false
        }
        
        if let uploadFileUrl = uploadFileUrl, uploadFilePath = uploadFileUrl.path where NSFileManager.defaultManager().fileExistsAtPath(uploadFilePath) {
            task = manager.session.uploadTaskWithRequest(request, fromFile: uploadFileUrl)
        } else if let bodyData = request.HTTPBody {
            if let tmpFileUrl = tmpFileUrl {
                if bodyData.writeToURL(tmpFileUrl, atomically: true) {
                    task = manager.session.uploadTaskWithRequest(request, fromFile: tmpFileUrl)
                } else {
                    println("[Silk] unable to write tmp upload file")
                }
            }
        } else {
            println("[Silk] unable to execute request - no data to upload")
            return false
        }
        
        if let task = task {
            task.taskDescription = tag
            manager.registerRequest(self)
            task.resume()
            return true
        } else {
            return false
        }
    }
    
    override func handleResponse(response: NSHTTPURLResponse, error: NSError?, task: NSURLSessionTask) {
        super.handleResponse(response, error: error, task: task)
        clearTmpFile()
    }
    
    // MARK: - Private Methods
    private func clearTmpFile() {
        if let tmpFileUrl = tmpFileUrl, tmpFilePath = tmpFileUrl.path where NSFileManager.defaultManager().fileExistsAtPath(tmpFilePath) {
            NSFileManager.defaultManager().removeItemAtURL(tmpFileUrl, error: nil)
        }
    }
}