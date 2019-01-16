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
            let replyFuture: Future<String?>

            if let text = msg.message.text {
                let args = text.components(separatedBy: CharacterSet.whitespacesAndNewlines)
                if (text.starts(with: "/add")) {
                    if (args.count > 1) {
                        let url = args[1]
                        replyFuture = self.subscribe(msg.recipient.chatId, to: url, on: req).map{ (sub) -> (String) in
                            return "\(sub.listDescription())"
                        }
                    } else {
                        replyFuture = req.future("Format: /add [feed url]")
                    }
                } else if (text.starts(with: "/remove")) {
                    if (args.count > 1) {
                        let subIdStr = args[1]
                        if let subId = Int(subIdStr) {
                            replyFuture = self.unsubscribe(msg.recipient.chatId, subId: subId, on: req).transform(to: "Subscription deleted")
                        } else {
                            replyFuture = req.future("Invalid subscription id")
                        }
                    } else {
                        replyFuture = req.future("Format: /remove [feed id]")
                    }
                } else if (text.starts(with: "/list")) {
                    replyFuture = try self.listSubscriptionsFor(msg.recipient.chatId, on: req).map({ (subs) -> (String) in
                        if (subs.count == 0) {
                            return "No subscriptions"
                        } else {
                            var reply = ""
                            for sub in subs {
                                reply += "\(sub.listDescription())\n";
                            }
                            return reply.trimmingCharacters(in: CharacterSet.newlines)
                        }
                    })
                } else {
                    replyFuture = req.future("/add [feed url] - subscribe feed\n/remove [feed url] - unsubscribe feed\n/list - list subscriptions")
                }
            } else {
                replyFuture = req.future(nil)
            }
            
            return replyFuture.flatMap{ (reply) -> EventLoopFuture<HTTPStatus> in
                if let reply = reply {
                    print("reply: \(reply)")
                    
                    let credentials = try req.make(Credentials.self)
                    
                    return try req.client()
                                    .post("https://\(credentials.host)/messages?access_token=\(credentials.token)&chat_id=\(msg.recipient.chatId)") { (post) in
                                        let outgoingMessage = OutgoingMessage(with: reply)
                                        try post.content.encode(outgoingMessage)
                                    }.map{ (resp) in
                                        print("msg send response: \(resp.http.body)")
                                        return resp.http.status
                                    }
                } else {
                    print("no reply")
                    fflush(stdout)
                    return req.future(.ok)
                }
            }
        }
    }
    
    func subscribe(_ chatId: Int, to url: String, on req: Request) -> Future<Subscription> {
        let sub = Subscription(url: url, chatId: chatId)
        return sub.save(on: req)
    }

    func unsubscribe(_ chatId: Int, subId: Int, on req: Request) -> Future<Void> {
        return Subscription.find(subId, on: req).flatMap{ (subOpt) -> EventLoopFuture<Void> in
            if let sub = subOpt,
                sub.chatId == chatId {
                return sub.delete(on: req)
            } else {
                return req.eventLoop.future()
            }
        }
    }

    func listSubscriptionsFor(_ chatId: Int, on req: Request) throws -> Future<[Subscription]> {
        return Subscription.query(on: req).filter(\.chatId, .equal, chatId).all()
    }

}
