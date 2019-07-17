import Foundation

public final class URLImageLoadingManager {
    public final class Task {
        private weak var owner: URLImageLoadingManager?
        
        public let request: URLRequest
        public var data: Data {
            return workQueue.sync { _data }
        }
        public var errorHandler: ((Error) -> Void)? {
            get { return workQueue.sync { _errorHander } }
            set { workQueue.sync { _errorHander = newValue } }
        }
        public var completeHandler: (() -> Void)? {
            get { return workQueue.sync { _completeHandler } }
            set { workQueue.sync { _completeHandler = newValue} }
        }
        public var shouldResumeHandler: (() -> Bool)? {
            get { return workQueue.sync { _shouldResumeHandler } }
            set { workQueue.sync { _shouldResumeHandler = newValue } }
        }
        
        private let workQueue: DispatchQueue
        private let callbackQueue: OperationQueue
        
        internal let urlTask: URLSessionTask
        internal private(set) var isFinished: Bool {
            get {
                dispatchPrecondition(condition: .onQueue(workQueue))
                return _isFinished
            }
            set {
                dispatchPrecondition(condition: .onQueue(workQueue))
                _isFinished = newValue
            }
        }
        private var isCanceled: Bool {
            get {
                dispatchPrecondition(condition: .onQueue(workQueue))
                return _isCanceled
            }
            set {
                dispatchPrecondition(condition: .onQueue(workQueue))
                _isCanceled = newValue
            }
        }
        
        private var _isFinished: Bool
        private var _isCanceled: Bool
        private var _data: Data
        private var _errorHander: ((Error) -> Void)?
        private var _completeHandler: (() -> Void)?
        private var _shouldResumeHandler: (() -> Bool)?
        
        internal init(owner: URLImageLoadingManager,
                      request: URLRequest,
                      urlTask: URLSessionTask,
                      callbackQueue: OperationQueue)
        {
            self.owner = owner
            self.workQueue = owner.workQueue
            self.request = request
            self.urlTask = urlTask
            self.callbackQueue = callbackQueue
            self._isFinished = false
            self._isCanceled = false
            self._data = Data()
        }
        
        public func start() {
            workQueue.sync {
                _ = owner?.start(task: self)
            }
        }
        
        public func cancel() {
            workQueue.sync {
                owner?.cancel(task: self)
            }
        }
        
        internal func appendData(_ data: Data) {
            dispatchPrecondition(condition: .onQueue(workQueue))
            
            _data.append(data)
        }

        internal func _cancel() {
            dispatchPrecondition(condition: .onQueue(workQueue))
            
            if isCanceled {
                return
            }
            isFinished = true
            isCanceled = true

            self.urlTask.cancel()
        }
        
        internal func handleSuccess() {
            dispatchPrecondition(condition: .onQueue(workQueue))
            
            if isFinished {
                return
            }
            isFinished = true

            callbackQueue.addOperation {
                let next: (() -> Void)? = self.workQueue.sync {
                    if self.isCanceled {
                        return nil
                    }
                    
                    return {
                        self.completeHandler?()
                    }
                }
                next?()
            }
        }
        
        internal func handleError(_ error: Error) {
            dispatchPrecondition(condition: .onQueue(workQueue))
            
            if isFinished {
                return
            }
            isFinished = true
            
            callbackQueue.addOperation {
                let next: (() -> Void)? = self.workQueue.sync {
                    if self.isCanceled {
                        return nil
                    }
                    
                    return {
                        self.errorHandler?(error)
                    }
                }
                next?()
            }
        }

        internal func requestShouldResume(_ handler: @escaping (Bool) -> Void) {
            dispatchPrecondition(condition: .onQueue(workQueue))
            
            var should: Bool = false
            
            let op = BlockOperation {
                let next: (() -> Void)? = self.workQueue.sync {
                    if self.isFinished {
                        return nil
                    }
                    
                    return {
                        should = self.shouldResumeHandler?() ?? false
                    }
                }

                next?()
            }
            
            op.completionBlock = {
                self.workQueue.async {
                    handler(should)
                }
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
    private let workQueue: DispatchQueue
    private let callbackQueue: OperationQueue
    private let delegateAdapter: DelegateAdapter
    private let session: URLSession
    
    private var urlTaskMap: [URLSessionTask: Task] = [:]
    private var waitingTasks: [Task] = []

    private var resumingWork: DispatchWorkItem?
    
    public init(urlCache: URLCache,
                callbackQueue: OperationQueue)
    {
        self.workQueue = DispatchQueue(label: "URLImageLoadingManager.workQueue")
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
    
    public func task(request: URLRequest,
                     callbackQueue: OperationQueue) -> Task
    {
        return workQueue.sync {
            let urlTask = session.dataTask(with: request)
            let task = Task(owner: self,
                            request: request,
                            urlTask: urlTask,
                            callbackQueue: callbackQueue)
            return task
        }
    }
    
    private func task(for urlTask: URLSessionTask) -> Task? {
        dispatchPrecondition(condition: .onQueue(workQueue))
        
        return urlTaskMap[urlTask]
    }
    
    private var runningTasks: [Task] {
        dispatchPrecondition(condition: .onQueue(workQueue))
        
        return urlTaskMap.values.map { $0 }
    }
    
    private func start(task: Task) -> Bool {
        dispatchPrecondition(condition: .onQueue(workQueue))
        
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
    
    private func cancel(task: Task) {
        dispatchPrecondition(condition: .onQueue(workQueue))
        
        self.removeTask(task)
        task._cancel()
    }
    
    private func removeTask(_ task: Task) {
        dispatchPrecondition(condition: .onQueue(workQueue))
        
        waitingTasks.removeAll { $0 === task }
        
        if let _ = urlTaskMap[task.urlTask] {
            _ = urlTaskMap.removeValue(forKey: task.urlTask)
        }
        
        startResuming()
    }
    
    private func isSameRequestRunning(_ request: URLRequest) -> Bool {
        dispatchPrecondition(condition: .onQueue(workQueue))
        
        return runningTasks.contains { $0.request == request }
    }
    
    private func startResuming() {
        dispatchPrecondition(condition: .onQueue(workQueue))
        
        let tasks: [Task] = waitingTasks
            .filter { !isSameRequestRunning($0.request) }
        
        func proc1(index: Int) {
            dispatchPrecondition(condition: .onQueue(workQueue))
            
            guard index < tasks.count else { return }
            
            let task = tasks[index]
            
            waitingTasks.removeAll { $0 === task }
            
            task.requestShouldResume { (should) in
                proc2(should: should, index: index)
            }
        }
        
        func proc2(should: Bool, index: Int) {
            dispatchPrecondition(condition: .onQueue(workQueue))
            
            let task = tasks[index]
            
            if should {
                let started = start(task: task)
                if started {
                    // end process
                    return
                }
            }
            
            // go next
            self.postResumingWork {
                proc1(index: index + 1)
            }
        }
        
        postResumingWork {
            proc1(index: 0)
        }
    }
    
    private func postResumingWork(_ f: @escaping () -> Void) {
        dispatchPrecondition(condition: .onQueue(workQueue))
        
        resumingWork?.cancel()
        
        let work = DispatchWorkItem(block: f)
        self.resumingWork = work
        workQueue.async(execute: work)
    }
    
    private func didReceiveData(urlTask: URLSessionTask, data: Data) {
        workQueue.sync {
            guard let task = self.task(for: urlTask) else { return }
            
            task.appendData(data)
        }
    }
    
    private func didError(urlTask: URLSessionTask, error: Error) {
        workQueue.sync {
            guard let task = self.task(for: urlTask) else { return }
            
            task.handleError(error)
            
            removeTask(task)
        }
    }
    
    private func didComplete(urlTask: URLSessionTask) {
        workQueue.sync {
            guard let task = self.task(for: urlTask) else { return }
            
            task.handleSuccess()
            
            removeTask(task)
        }
    }
}

