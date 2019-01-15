//
//  CmdController.swift
//  App
//
//  Created by Юрий Буянов on 15/01/2019.
//

import Vapor

final class CmdController {
    func handleMessage(_ req: Request) throws -> Future<HTTPStatus> {
        
        return try req.content.decode(Message.self).flatMap { msg in
            let reply: String?

            if let text = msg.message.text {
                let args = text.components(separatedBy: CharacterSet.whitespacesAndNewlines)
                if (text.starts(with: "/add")) {
                    if (args.count > 1) {
                        let url = args[1]
                        reply = "Subscribed to \(url)"
                    } else {
                        reply = "Format: /add [feed url]"
                    }
                } else if (text.starts(with: "/remove")) {
                    if (args.count > 1) {
                        let url = args[1]
                        reply = "Removed feed \(url)"
                    } else {
                        reply = "Format: /remove [feed url]"
                    }
                } else if (text.starts(with: "/list")) {
                    reply = "Feed list: ..."
                } else {
                    reply = "/add [feed url] - subscribe feed\n/remove [feed url] - unsubscribe feed\n/list - list subscriptions"
                }
            } else {
                reply = nil
            }
            
            if let reply = reply {
                print("reply: \(reply)")
                
                let credentials = try req.make(Credentials.self)
                
                return HTTPClient.connect(scheme: .https,
                                          hostname: credentials.host,
                                          on: req).flatMap { (client) -> EventLoopFuture<HTTPStatus> in
                                            let outgoingMessage = OutgoingMessage(with: reply)
                                            let outgoingJson = try! JSONEncoder().encode(outgoingMessage)
                                            let msgRequest = HTTPRequest(method: .POST, url: "/messages?access_token=\(credentials.token)&chat_id=\(msg.recipient.chatId)", body: outgoingJson)
                                            return client.send(msgRequest).do{ (resp) in
                                                    print("msg send response: \(resp.body)")
                                                    fflush(stdout)
                                                }.catch { (err) in
                                                    print("reply error: \(err)")
                                                    fflush(stdout)
                                                }
                                                .map { (resp) -> (HTTPStatus) in
                                                    return .ok
                                                }
                }
            } else {
                print("no reply")
            }
            
            fflush(stdout)
            
            return req.future(.ok)
        }
    }
}
