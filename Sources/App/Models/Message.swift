import Vapor

//{"sender":{"user_id":553647998109,"name":"Юрий 𓃗 Буянов"},"recipient":{"chat_id":27094156922},"message":{"mid":"mid

struct Recipient: Codable {
    var chatId: Int
    
    private enum CodingKeys : String, CodingKey {
        case chatId = "chat_id"
    }
}

struct Sender: Codable {
    var userId: Int
    var userName: String
    
    private enum CodingKeys : String, CodingKey {
        case userId = "user_id", userName = "name"
    }
}

struct MsgContent: Codable {
    var messageId: String
    var text: String?
    
    private enum CodingKeys : String, CodingKey {
        case messageId = "mid", text
    }
}

struct Message: Codable {
    var sender: Sender
    var recipient: Recipient
    var body: MsgContent
    var timestamp: Int
}

struct OutgoingMessage: Codable {
    var text: String
    
    init(with text: String) {
        self.text = text
    }
}

extension OutgoingMessage: Content {}
