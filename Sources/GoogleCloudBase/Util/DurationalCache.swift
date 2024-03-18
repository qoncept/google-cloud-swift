public protocol DurationalCacheProtocol<Value> {
    associatedtype Value
    mutating func store(value: Value, expiresIn: Duration)
    var cachedValue: Value? { get }
}

public struct DurationalCache<ClockType: Clock<Duration>, Value>: DurationalCacheProtocol {
    public init(clock: ClockType) {
        self.clock = clock
        self.expiryTime = clock.now
    }
    
    var clock: ClockType

    var _cachedValue: Value?
    var expiryTime: ClockType.Instant

    public mutating func store(value: Value, expiresIn: Duration) {
        _cachedValue = value
        expiryTime = clock.now.advanced(by: expiresIn)
    }

    public var cachedValue: Value? {
        guard let _cachedValue else {
            return nil
        }
        if expiryTime < clock.now {
            return nil
        }
        return _cachedValue
    }
}
