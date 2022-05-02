//import NIO
//import Citadel
//import NIOSSH
//
//public struct SSHClient {
//    let client: Citadel.SSHClient
//    
//    public static func connect(
//        host: String,
//        port: Int = 22,
//        authenticationMethod: SSHAuthenticationMethod,
//        hostKeyValidator: SSHHostKeyValidator,
//        group: MultiThreadedEventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
//    ) async throws -> SSHClient {
//        return try await SSHClient(
//            client: .connect(
//                host: host,
//                port: port,
//                authenticationMethod: authenticationMethod,
//                hostKeyValidator: hostKeyValidator,
//                reconnect: .never,
//                group: group
//            )
//        )
//    }
//    
//    public func buildTunnel<OutboundIn>(
//        host: String,
//        port: Int,
//        @ChannelBuilder<SSHTunnel.InboundIn, SSHTunnel.OutboundOut> buildHandlers: @escaping () -> ConfiguredChannel<SSHTunnel.InboundIn, Never, OutboundIn, SSHTunnel.OutboundOut>
//    ) async throws -> SSHTunnel<OutboundIn> {
//        let channel = try await client.createDirectTCPIPChannel(
//            using: .init(
//                targetHost: host,
//                targetPort: port,
//                originatorAddress: SocketAddress(ipAddress: "fe80::1", port: port)
//            )
//        ) { channel in
//            channel.pipeline.addHandlers(buildHandlers().handlers)
//        }
//        
//        return SSHTunnel<_>(channel: channel)
//    }
//}
//
//public struct SSHTunnel<OutboundIn>: ReadableChannel, WritableChannel, ClosableChannel {
//    public typealias InboundIn = ByteBuffer
//    public typealias OutboundOut = ByteBuffer
//    
//    let channel: Channel
//    
//    public func write(_ data: OutboundIn) async throws {
//        try await channel.writeAndFlush(data)
//    }
//    
//    public func close() async throws {
//        try await channel.close()
//    }
//}
