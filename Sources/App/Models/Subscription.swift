import FluentSQLite
import Vapor

final class Subscription<D>: Model where D: Database {
    typealias Database = D
    
    typealias ID = UUID
    
    var id: ID
    var title: String? = nil
    var url: String
    var chatId: Int
    var updated: Float
    
    /// Creates a new `Todo`.
    init(url: String, chatId: Int) {
        self.id = UUID()
        self.updated = Date().timeIntervalSince1970()

//        self.id = id
        self.url = url
        self.chatId = chatId
    }
}
