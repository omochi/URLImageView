import Foundation

public final class URLImageLoadingManager {
    public final class Task {
        weak var owner: URLImageLoadingManager?
        let request: URLRequest
        let urlTask: URLSessionTask
        public internal(set) var data: Data
        
        public var errorHandler: ((Error) -> Void)?
        public var completeHandler: (() -> Void)?
        public var shouldRestartHandler: (() -> Bool)?

        init(owner: URLImageLoadingManager,
             request: URLRequest,
             urlTask: URLSessionTask)
        {
            self.owner = owner
            self.request = request
            self.urlTask = urlTask
            self.data = Data()
        }
        
        public func start() {
            owner?.start(task: self)
        }
        
        public func cancel() {
            owner?.cancel(task: self)
        }
    }
    
    private final class DelegateAdapter : NSObject,
        URLSessionDataDelegate
    {
        public weak var owner: URLImageLoadingManager?
        
        func urlSession(_ session: URLSession,
                        dataTask: URLSessionDataTask,
                        didReceive data: Data)
        {
            owner?.didReceiveData(urlTask: dataTask, data: data)
        }
        
        func urlSession(_ session: URLSession,
                        task: URLSessionTask,
                        didCompleteWithError error: Error?)
        {
            if let error = error {
                owner?.didError(urlTask: task, error: error)
            } else {
                owner?.didComplete(urlTask: task)
            }
        }
    }
    
    public static let shared: URLImageLoadingManager =
        URLImageLoadingManager(urlCache: URLCache.shared)
    
    public let urlCache: URLCache
    public let queue: OperationQueue
    private let delegateAdapter: DelegateAdapter
    private let session: URLSession
    
    private var urlTaskMap: [URLSessionTask: Task] = [:]
    private var waitingTasks: [Task] = []
    private var isUpdateRunning: Bool = false

    public init(urlCache: URLCache) {
        queue = OperationQueue()
        queue.name = "URLImageLoadingManager.queue"
        
        self.urlCache = urlCache
        let config = URLSessionConfiguration.default.copy() as! URLSessionConfiguration
        config.urlCache = urlCache
        
        let delegateAdapter = DelegateAdapter()
        self.delegateAdapter = delegateAdapter
        
        self.session = URLSession(configuration: config,
                                  delegate: delegateAdapter,
                                  delegateQueue: queue)
        
        delegateAdapter.owner = self
    }
    
    public func task(request: URLRequest) -> Task {
        let urlTask = session.dataTask(with: request)
        let task = Task(owner: self,
                        request: request,
                        urlTask: urlTask)
        return task
    }
    
    private var runningTasks: [Task] {
        return urlTaskMap.values.map { $0 }
    }
    
    private func start(task: Task) {
        queue.addOperation {
            if (self.runningTasks.contains { $0.request == task.request }) {
                print("conflict, wait")
                self.waitingTasks.append(task)
            } else {
                self.urlTaskMap[task.urlTask] = task
                task.urlTask.resume()
            }
        }
    }
    
    private func cancel(task: Task) {
        let op = BlockOperation {
            self.removeTask(task)
        }
        queue.addOperation(op)
        op.waitUntilFinished()
    }
    
    private func removeTask(_ task: Task)
    {
        precondition(OperationQueue.current == queue)
        
        waitingTasks.removeAll { $0 === task }
        
        if let _ = urlTaskMap[task.urlTask] {
            _ = urlTaskMap.removeValue(forKey: task.urlTask)
        }
        
        task.urlTask.cancel()
        
        queue.addOperation {
            self.tryResume()
        }
    }
    
    private func isSameRequestRunning(_ request: URLRequest) -> Bool {
        return runningTasks.contains { $0.request == request }
    }
    
    private func tryResume() {
        precondition(OperationQueue.current == queue)
        
        let waitingTasks = self.waitingTasks
        for task in waitingTasks {
            if isSameRequestRunning(task.request) {
                continue
            }
            
            self.waitingTasks.removeAll { $0 === task }
            
            let doesRestart = task.shouldRestartHandler?() ?? false
            
            if doesRestart {
                start(task: task)
                return
            }
        }
    }

    private func task(for urlTask: URLSessionTask) -> Task? {
        return urlTaskMap[urlTask]
    }
    
    private func didReceiveData(urlTask: URLSessionTask, data: Data) {
        guard let task = task(for: urlTask) else { return }
        
        task.data.append(data)
    }
    
    private func didError(urlTask: URLSessionTask, error: Error) {
        guard let task = task(for: urlTask) else { return }
        
        task.errorHandler?(error)
        
        removeTask(task)
    }
    
    private func didComplete(urlTask: URLSessionTask) {
        guard let task = task(for: urlTask) else { return }
        
        task.completeHandler?()
        
        removeTask(task)
    }
}
