import Vapor

// {
//   "message": {
//     "recipient": {
//       "chat_id": 26560838232,
//       "chat_type": "dialog",
//       "user_id": 578895232709
//     },
//     "timestamp": 1572364013360,
//     "body": {
//       "mid": "EwAEAcmY2EYV9ZY6_AYsBOoDj9R5BXb6y3QIuvIyLuM",
//       "seq": 103046447979570057,
//       "text": "test"
//     },
//     "sender": {
//       "user_id": 553647998109,
//       "name": "Юрий 𓃗 Буянов"
//     }
//   },
//   "timestamp": 1572364013360,
//   "update_type": "message_created"
// }

struct Update: Codable {
    var update_type: String //todo: enum
    var message: Message?
    var timestamp: Int 
}