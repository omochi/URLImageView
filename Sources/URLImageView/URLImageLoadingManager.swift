import Foundation

public final class URLImageLoadingManager {
    public final class Task {
        internal private(set) weak var owner: URLImageLoadingManager?
        public let request: URLRequest
        internal let syncQueue: DispatchQueue
        private let callbackQueue: OperationQueue
        internal let urlTask: URLSessionTask
        
        internal var isFinished: Bool
        internal var sync_isFinished: Bool {
            return syncQueue.sync { isFinished }
        }
        
        internal var _data: Data
        
        public var data: Data {
            return syncQueue.sync { _data }
        }
        
        public var errorHandler: ((Error) -> Void)?
        public var completeHandler: (() -> Void)?
        public var shouldResumeHandler: (() -> Bool)?

        init(owner: URLImageLoadingManager,
             request: URLRequest,
             urlTask: URLSessionTask,
             callbackQueue: OperationQueue)
        {
            self.owner = owner
            self.request = request
            self.urlTask = urlTask
            self.syncQueue = DispatchQueue(label: "URLImageLoadingManager.Task.syncQueue")
            self.callbackQueue = callbackQueue
            self.isFinished = false
            self._data = Data()
        }
        
        // thread safe
        public func start() {
            _ = owner?.start(task: self)
        }
        
        // thread safe
        public func cancel() {
            owner?.cancel(task: self)
        }
        
        private func sync_takeFinish() -> Bool {
            return syncQueue.sync {
                if isFinished {
                    return false
                }
                isFinished = true
                return true
            }
        }
        
        internal func _cancel() {
            if sync_takeFinish() {
                urlTask.cancel()
            }
        }
        
        internal func handleSuccess() {
            callbackQueue.addOperation {
                if self.sync_takeFinish() {
                    self.completeHandler?()
                }
            }
        }
        
        internal func handleError(_ error: Error) {
            callbackQueue.addOperation {
                if self.sync_takeFinish() {
                    self.errorHandler?(error)
                }
            }
        }
        
        internal func requestShouldResume(_ handler: @escaping (Bool) -> Void) {
            var does: Bool = false
            
            let op = BlockOperation {
                if self.sync_isFinished {
                    return
                }
                
                does = self.shouldResumeHandler?() ?? false
            }
            
            op.completionBlock = {
                handler(does)
            }
            
            callbackQueue.addOperation(op)
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
        URLImageLoadingManager(urlCache: .shared,
                               callbackQueue: .main)
    
    public let urlCache: URLCache
    private let syncQueue: DispatchQueue
    private let workQueue: DispatchQueue
    private let callbackQueue: OperationQueue
    private let delegateAdapter: DelegateAdapter
    private let session: URLSession
    
    private var urlTaskMap: [URLSessionTask: Task] = [:]
    private var waitingTasks: [Task] = []
    private var isUpdateRunning: Bool = false

    public init(urlCache: URLCache,
                callbackQueue: OperationQueue)
    {
        syncQueue = DispatchQueue(label: "URLImageLoadingManager.syncQueue")
        workQueue = DispatchQueue(label: "URLImageLoadingManager.workQueue")
        self.callbackQueue = callbackQueue
        
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
    
    // thread safe
    public func task(request: URLRequest,
                     callbackQueue: OperationQueue) -> Task
    {
        return syncQueue.sync {
            let urlTask = session.dataTask(with: request)
            let task = Task(owner: self,
                            request: request,
                            urlTask: urlTask,
                            callbackQueue: callbackQueue)
            return task
        }
    }
    
    private func task(for urlTask: URLSessionTask) -> Task? {
        return urlTaskMap[urlTask]
    }
    
    private var runningTasks: [Task] {
        return urlTaskMap.values.map { $0 }
    }
    
    private func start(task: Task) -> Bool {
        return syncQueue.sync {
            task.syncQueue.sync {
                if task.isFinished {
                    return false
                }
                
                if (self.runningTasks.contains { $0.request == task.request }) {
                    self.waitingTasks.append(task)
                } else {
                    self.urlTaskMap[task.urlTask] = task
                    task.urlTask.resume()
                }
                
                return true
            }
        }
    }
    
    private func cancel(task: Task) {
        syncQueue.sync {
            self.removeTask(task)
            task._cancel()
        }
    }
    
    private func removeTask(_ task: Task)
    {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        
        waitingTasks.removeAll { $0 === task }
        
        if let _ = urlTaskMap[task.urlTask] {
            _ = urlTaskMap.removeValue(forKey: task.urlTask)
        }
        
        workQueue.async {
            self.tryResume()
        }
    }
    
    private func isSameRequestRunning(_ request: URLRequest) -> Bool {
        return runningTasks.contains { $0.request == request }
    }
    
    private func tryResume() {
        dispatchPrecondition(condition: .onQueue(workQueue))
        
        var tasks: [Task] = syncQueue.sync {
            waitingTasks.filter { !isSameRequestRunning($0.request) }
        }
        
        func proc1(index: Int) {
            dispatchPrecondition(condition: .onQueue(workQueue))
            
            guard index < tasks.count else { return }
            
            let task = tasks[index]
            
            syncQueue.sync {
                waitingTasks.removeAll { $0 === task }
            }
            
            task.requestShouldResume { (does) in
                if !does {
                    self.workQueue.async {
                        proc1(index: index + 1)
                    }
                    return
                }
                
                self.workQueue.async {
                    proc2(task: task, index: index)
                }
            }
        }
        
        func proc2(task: Task, index: Int) {
            dispatchPrecondition(condition: .onQueue(workQueue))
            
            if !start(task: task) {
                workQueue.async {
                    proc1(index: index + 1)
                }
                return
            }
        }
        
        proc1(index: 0)
    }
    
    private func sync_task(for urlTask: URLSessionTask) -> Task? {
        return syncQueue.sync {
            task(for: urlTask)
        }
    }

    private func didReceiveData(urlTask: URLSessionTask, data: Data) {
        guard let task = sync_task(for: urlTask) else { return }
        
        task.syncQueue.sync {
            task._data.append(data)
        }
    }
    
    private func didError(urlTask: URLSessionTask, error: Error) {
        guard let task = sync_task(for: urlTask) else { return }
        
        task.handleError(error)
        
        syncQueue.sync {
            removeTask(task)
        }
    }
    
    private func didComplete(urlTask: URLSessionTask) {
        guard let task = sync_task(for: urlTask) else { return }
        
        task.handleSuccess()
        
        syncQueue.sync {
            removeTask(task)
        }
    }
}

