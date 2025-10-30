#if swift(>=6.2)
public typealias GCSSendableMetatype = SendableMetatype
#else
public typealias GCSSendableMetatype = Any
#endif
