import Foundation
import os

public final class URLImageContainer {
    public enum State {
        case inited
        case pending
        case loading
        case loaded
        case failed
    }
    
    public var loadingManager: URLImageLoadingManager
    public var url: URL?
    public var imageUpdateHandler: ((UIImage?) -> Void)?
    
    private var state: State
    private let callbackQueue: OperationQueue

    private var loadingTask: URLImageLoadingManager.Task?
    
    public init() {
        self.loadingManager = URLImageLoadingManager.shared
        self.state = .inited
        self.callbackQueue = OperationQueue.main
    }

    public func start() {
        precondition(OperationQueue.current == callbackQueue)
        
        callbackQueue.cancelAllOperations()
        
        switch state {
        case .inited, .loaded, .failed: break
        case .pending, .loading:
            log("invalid state: \(state) in start")
            return
        }
        
        guard let url = self.url else {
            handleSuccess(image: nil)
            return
        }
        
        self.state = .loading
        
        let request = URLRequest(url: url)
        
        if tryLoadFromCache(request: request) {
            return
        }
        
        startDownload(request: request)
    }
    
    public func cancel() {
        precondition(OperationQueue.current == callbackQueue)
        
        callbackQueue.cancelAllOperations()
        
        loadingTask?.cancel()
        loadingTask = nil
        
        self.state = .inited
    }
    
    private func tryLoadFromCache(request: URLRequest)
        -> Bool
    {
        if let response = loadingManager.urlCache.cachedResponse(for: request) {
            log("cache hit")
            if let image = try? processData(response.data) {
                log("cache load")
                
                func finish() {
                    self.state = .loaded
                    self.emitImage(image)
                }
                
                if OperationQueue.current == callbackQueue {
                    finish()
                } else {
                    callbackQueue.addOperation(finish)
                }
                
                return true
            }
            
            loadingManager.urlCache.removeCachedResponse(for: request)
        }
        
        return false
    }
    
    private func processData(_ data: Data) throws -> UIImage {
        guard let image = UIImage(data: data) else {
            throw MessageError("image decode failed")
        }
        return image
    }
    
    private func startDownload(request: URLRequest) {
        log("start download")
        
        let task = loadingManager.task(request: request)
        task.errorHandler = { [weak self] (error) in
            guard let self = self else { return }
            
            self.callbackQueue.addOperation {
                self.handleError(error)
            }
        }
        task.completeHandler = { [weak self, weak task] () in
            guard let self = self,
                let task = task else { return }
            
            do {
                let data = task.data
                let image = try self.processData(data)
                
                self.callbackQueue.addOperation {
                    self.handleSuccess(image: image)
                }
            } catch {
                self.callbackQueue.addOperation {
                    self.handleError(error)
                }
            }
        }
        task.shouldRestartHandler = { [weak self] () in
            guard let self = self else {
                return false
            }
            
            if self.tryLoadFromCache(request: request) {
                return false
            }
            
            return true
        }
        
        task.start()
    }
    
    private func handleSuccess(image: UIImage?) {
        precondition(OperationQueue.current == callbackQueue)
        
        self.state = .loaded
        loadingTask = nil
        self.emitImage(image)
    }

    private func handleError(_ error: Error) {
        precondition(OperationQueue.current == callbackQueue)
        
        log("error: url=\(url?.description ?? ""), \(error)")
        
        self.state = .failed
        loadingTask = nil
        self.emitImage(nil)
    }
    
    private func emitImage(_ image: UIImage?) {
        precondition(OperationQueue.current == callbackQueue)
        imageUpdateHandler?(image)
    }
    
    private func log(_ message: String) {
        os_log("%@", message)
    }
    
}
