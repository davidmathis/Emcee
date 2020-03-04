import AutomaticTermination
import Foundation
import Logging
import PortDeterminer
import RESTMethods
import RESTServer

public final class QueueHTTPRESTServer {
    private let httpRestServer: HTTPRESTServer
    
    public init(httpRestServer: HTTPRESTServer) {
        self.httpRestServer = httpRestServer
    }
    
    public func setHandler<A1, A2, B1, B2, C1, C2, E1, E2, F1, F2, G1, G2, H1, H2, I1, I2>(
        bucketResultHandler: RESTEndpointOf<C1, C2>,
        dequeueBucketRequestHandler: RESTEndpointOf<B1, B2>,
        jobDeleteHandler: RESTEndpointOf<I1, I2>,
        jobResultsHandler: RESTEndpointOf<H1, H2>,
        jobStateHandler: RESTEndpointOf<G1, G2>,
        registerWorkerHandler: RESTEndpointOf<A1, A2>,
        scheduleTestsHandler: RESTEndpointOf<E1, E2>,
        versionHandler: RESTEndpointOf<F1, F2>
    ) {
        httpRestServer.setHandler(
            pathWithSlash: RESTMethod.bucketResult.withPrependingSlash,
            handler: bucketResultHandler,
            requestIndicatesActivity: true
        )
        httpRestServer.setHandler(
            pathWithSlash: RESTMethod.getBucket.withPrependingSlash,
            handler: dequeueBucketRequestHandler,
            requestIndicatesActivity: false
        )
        httpRestServer.setHandler(
            pathWithSlash: RESTMethod.jobDelete.withPrependingSlash,
            handler: jobDeleteHandler,
            requestIndicatesActivity: true
        )
        httpRestServer.setHandler(
            pathWithSlash: RESTMethod.jobResults.withPrependingSlash,
            handler: jobResultsHandler,
            requestIndicatesActivity: true
        )
        httpRestServer.setHandler(
            pathWithSlash: RESTMethod.jobState.withPrependingSlash,
            handler: jobStateHandler,
            requestIndicatesActivity: false
        )
        httpRestServer.setHandler(
            pathWithSlash: RESTMethod.queueVersion.withPrependingSlash,
            handler: versionHandler,
            requestIndicatesActivity: false
        )
        httpRestServer.setHandler(
            pathWithSlash: RESTMethod.registerWorker.withPrependingSlash,
            handler: registerWorkerHandler,
            requestIndicatesActivity: true
        )
        httpRestServer.setHandler(
            pathWithSlash: RESTMethod.scheduleTests.withPrependingSlash,
            handler: scheduleTestsHandler,
            requestIndicatesActivity: true
        )
    }

    public func start() throws -> Int {
        return try httpRestServer.start()
    }
}
