import FluentPostgreSQL
import Vapor

final class Subscription: PostgreSQLModel {
    var id: Int?
    
    var title: String? = nil
    var url: String
    var chatId: Int

    /// Creates a new `Todo`.
    init(url: String, chatId: Int) {
        self.id = nil
        self.url = url
        self.chatId = chatId
    }
}
