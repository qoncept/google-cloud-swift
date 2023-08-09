import AsyncHTTPClient
import NIO

extension HTTPClient.EventLoopGroupProvider {
    static var singleton: Self {
        .shared(NIOSingletons.posixEventLoopGroup)
    }
}
