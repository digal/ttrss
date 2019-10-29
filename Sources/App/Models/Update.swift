import Vapor

// {
//   "message": {
//   },
//   "timestamp": 1572364013360,
//   "update_type": "message_created"
// }

struct Update: Codable {
    var update_type: String //todo: enum
    var message: Message?
    var timestamp: Int 
}