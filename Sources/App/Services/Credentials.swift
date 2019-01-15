import Vapor
import Jobs

public struct BotInfo: Codable {
    let name: String
    let userId: Int
    
    private enum CodingKeys : String, CodingKey {
        case name, userId = "user_id"
    }
}

public final class Credentials: Service {
    let token: String
    let host: String
    var info: BotInfo?
    
    init(token: String, host: String) {
        self.token = token
        self.host = host
    }
}

public final class CredentialsProvider : Provider  {
    let credentials: Credentials
    let token: String
    let host = "test2.tamtam.chat"

    init(token: String) {
        self.token = token
        self.credentials = Credentials(token: token, host: self.host)
    }

    public func register(_ services: inout Services) throws {
        services.register(self.credentials)
    }
    
    public func didBoot(_ container: Container) throws -> EventLoopFuture<Void> {
        Jobs.add(interval: .seconds(600)) {
            try self.updateCredentials(container).catch { (err) in
                print("error: \(err)")
            }
        }
        return try self.updateCredentials(container).map { (_) -> (Void) in
            return ()
        }
    }
    
    func updateCredentials(_ container: Container)  throws -> EventLoopFuture<HTTPResponse> {
        return HTTPClient.connect(scheme: .https,
                           hostname: self.host,
                           on: container)
            .flatMap { (client) -> EventLoopFuture<HTTPResponse> in
                let infoRequest = HTTPRequest(method: .GET, url: "/me?access_token=\(self.token)")
                return client.send(infoRequest)
            }
            .do { (resp) in
                print("response: \(resp)")
                if let respData = resp.body.data,
                    let info = try? JSONDecoder().decode(BotInfo.self, from: respData) {
                    self.credentials.info = info
                }
            }
        
    }
}
