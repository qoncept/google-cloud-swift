public enum SetOrDelete<Value> {
    case set(Value)
    case delete

    public var value: Value? {
        switch self {
        case .set(let x): return x
        case .delete: return nil
        }
    }
}
