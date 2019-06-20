import Foundation

internal struct MessageError : LocalizedError, CustomStringConvertible {
    public var message: String
    
    public init(_ message: String) {
        self.message = message
    }
    
    public var description: String { return message }
    
    public var errorDescription: String? { return description }
}
