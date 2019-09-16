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
    let host = "botapi.tamtam.chat"

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
        return try self.updateCredentials(container).transform(to: ())
    }
    
    func updateCredentials(_ container: Container)  throws -> EventLoopFuture<BotInfo> {
        print("updateCredentials")

        return try container.client()
                            .get("https://\(self.host)/me?access_token=\(self.token)")
                            .flatMap{ (resp) -> EventLoopFuture<BotInfo> in
                                return try resp.content.decode(BotInfo.self)
                            }.do { (botInfo) in
                                self.credentials.info = botInfo
                            }
    }
}
