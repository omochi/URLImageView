import Foundation
import os

public final class URLImageLoader {
    public enum State {
        case inited
        case loading
        case loaded
        case failed
    }
    
    public var loadingManager: URLImageLoadingManager
    public var url: URL?
    public private(set) var image: UIImage? {
        didSet {
            imageHandler?(image)
        }
    }
    public var imageHandler: ((UIImage?) -> Void)?
    public var isLoading: Bool {
        switch state {
        case .loading: return true
        case .inited, .loaded, .failed: return false
        }
    }
    public var isLoadingHandler: ((Bool) -> Void)?
    
    private var state: State {
        get { return _state }
        set {
            let oldIsLoading = isLoading
            _state = newValue
            let newIsLoading = isLoading
            if oldIsLoading != newIsLoading {
                isLoadingHandler?(newIsLoading)
            }
        }
    }
    private var _state: State
    
    private let callbackQueue: OperationQueue

    private var loadingTask: URLImageLoadingManager.Task?
    
    public init() {
        self.loadingManager = URLImageLoadingManager.shared
        self._state = .inited
        self.callbackQueue = OperationQueue.main
    }

    public func start() {
        precondition(OperationQueue.current == callbackQueue)
        
        cancel()
        
        guard let url = self.url else {
            handleSuccess(image: nil)
            return
        }
        
        self.state = .loading
        
        let request = URLRequest(url: url)
        
        if tryLoadFromCacheInCallbackQueue(request: request) {
            return
        }
        
        self.image = nil
        
        startDownload(request: request)
    }
    
    public func cancel() {
        precondition(OperationQueue.current == callbackQueue)
        
        callbackQueue.cancelAllOperations()
        
        loadingTask?.cancel()
        loadingTask = nil
        
        self.state = .inited
    }
    
    private func _tryLoadFromCache(request: URLRequest) -> UIImage?
    {
        guard let response = loadingManager.urlCache.cachedResponse(for: request) else {
            return nil
        }
        
        guard let image = try? processData(response.data) else {
            loadingManager.urlCache.removeCachedResponse(for: request)
            return nil
        }
        
        return image
    }
    
    private func tryLoadFromCacheInCallbackQueue(request: URLRequest) -> Bool {
        precondition(OperationQueue.current == callbackQueue)
        
        guard let image = _tryLoadFromCache(request: request) else {
            return false
        }
        handleSuccess(image: image)
        return true
    }
    
    private func tryLoadFromCacheInNetworkQueue(request: URLRequest) -> Bool {
        precondition(OperationQueue.current == loadingManager.queue)
        
        guard let image = _tryLoadFromCache(request: request) else {
            return false
        }
        callbackQueue.addOperation {
            self.handleSuccess(image: image)
        }
        return true
    }
    
    private func processData(_ data: Data) throws -> UIImage {
        guard let image = UIImage(data: data) else {
            throw MessageError("image decode failed")
        }
        return image
    }
    
    private func startDownload(request: URLRequest) {
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
            
            if self.tryLoadFromCacheInNetworkQueue(request: request) {
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
        self.image = image
    }

    private func handleError(_ error: Error) {
        precondition(OperationQueue.current == callbackQueue)
        
        self.state = .failed
        loadingTask = nil
        self.image = nil
    }
    
}
