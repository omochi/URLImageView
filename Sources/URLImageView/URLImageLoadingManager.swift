import Foundation

public final class URLImageLoadingManager {
    public final class Task {
        enum State {
            case running
            case waiting
        }
        
        weak var owner: URLImageLoadingManager?
        let request: URLRequest
        let urlTask: URLSessionTask
        var state: State
        public internal(set) var data: Data
        
        public var shouldRestartHandler: (() -> Bool)?
        public var errorHandler: ((Error) -> Void)?
        public var completeHandler: (() -> Void)?
        
        init(owner: URLImageLoadingManager,
             request: URLRequest,
             urlTask: URLSessionTask)
        {
            self.owner = owner
            self.request = request
            self.urlTask = urlTask
            self.state = .waiting
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
    
    private let queue: DispatchQueue
    private let delegateAdapter: DelegateAdapter
    private let session: URLSession
    
    private var urlTaskMap: [URLSessionTask: Task] = [:]
    private var waitingTasks: [Task] = []

    public init(urlCache: URLCache) {
        queue = DispatchQueue(label: "URLImageLoadingManager")
        
        self.urlCache = urlCache
        let config = URLSessionConfiguration.default.copy() as! URLSessionConfiguration
        config.urlCache = urlCache
        
        let delegateAdapter = DelegateAdapter()
        self.delegateAdapter = delegateAdapter
        
        self.session = URLSession(configuration: config,
                                  delegate: delegateAdapter,
                                  delegateQueue: nil)
        
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
        var doesResume = false
        
        queue.sync {
            if (runningTasks.contains { $0.request == task.request }) {
                print("conflict, wait")
                task.state = .waiting
                waitingTasks.append(task)
            } else {
                task.state = .running
                urlTaskMap[task.urlTask] = task
                doesResume = true
            }
        }
        
        if doesResume {
            print("resume")
            task.urlTask.resume()
        }
    }
    
    private func cancel(task: Task) {
        removeTask(task)
    }
    
    private func syncTask(for urlTask: URLSessionTask) -> Task? {
        return queue.sync { urlTaskMap[urlTask] }
    }
    
    private func removeTask(_ task: Task)
    {
        queue.sync {
            waitingTasks.removeAll { $0 === task }
            
            if let _ = urlTaskMap[task.urlTask] {
                _ = urlTaskMap.removeValue(forKey: task.urlTask)
            }
        }
        
        task.urlTask.cancel()
        
        while true {
            var resumingTaskOrNone: Task?
            
            queue.sync {
                if let index = (waitingTasks.firstIndex { $0.request == task.request }) {
                    resumingTaskOrNone = waitingTasks[index]
                    waitingTasks.remove(at: index)
                }
            }
            
            guard let resumingTask = resumingTaskOrNone else {
                break
            }

            if resumingTask.shouldRestartHandler?() ?? false {
                start(task: resumingTask)
                break
            }
        }
    }

    private func didReceiveData(urlTask: URLSessionTask, data: Data) {
        guard let task = syncTask(for: urlTask) else { return }
        
        task.data.append(data)
    }
    
    private func didError(urlTask: URLSessionTask, error: Error) {
        guard let task = syncTask(for: urlTask) else { return }
        
        task.errorHandler?(error)
        
        removeTask(task)
    }
    
    private func didComplete(urlTask: URLSessionTask) {
        guard let task = syncTask(for: urlTask) else { return }
        
        task.completeHandler?()
        
        removeTask(task)
    }
}
