import Dispatch

extension DispatchQueue {
    internal typealias Next = (() -> Void)
    internal func syncAndNext(_ f: () throws -> Next?) rethrows -> Next? {
        return try self.sync(execute: f)
    }
}
