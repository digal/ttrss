//
//  FeedService.swift
//  App
//
//  Created by Юрий Буянов on 15/01/2019.
//

import Vapor
import FeedKit
import Jobs

enum FeedError: Error {
    case invalidFeed(url: String)
}

struct FeedEntry {
    let title: String
    let summary: String
    let link: String?
    let date: Date
    
    init(with atomEntry: AtomFeedEntry) {
        self.title = atomEntry.title ?? atomEntry.published?.description ?? atomEntry.id ?? "[Untitled]"
        self.summary = atomEntry.summary?.value ?? "[No content]"
        self.link = atomEntry.links?.first?.attributes?.href
        self.date = atomEntry.published ?? Date()
    }
    
    init(with rssItem: RSSFeedItem) {
        self.title = rssItem.title ?? rssItem.pubDate?.description ?? rssItem.guid?.value ?? "[Untitled]"
        self.summary = rssItem.description ?? "[No content]"
        self.link = rssItem.link
        self.date = rssItem.pubDate ?? Date()
    }
    
    init(with jsonItem: JSONFeedItem) {
        self.title = jsonItem.title ?? jsonItem.datePublished?.description ?? jsonItem.id ?? "[Untitled]"
        self.summary = jsonItem.summary ?? "[No content]"
        self.link = jsonItem.url
        self.date = jsonItem.datePublished ?? Date()
    }

    func asMessage() -> OutgoingMessage {
        var content = "\(self.title)\n\(self.summary)"
        if let link = self.link {
            content += "\n\n\(link)"
        }
        
        let msg = OutgoingMessage(with: content)
        return msg
    }
}


final class FeedService: Service {
    
    func send(on container: Container, chatId: Int, msg: OutgoingMessage, credentials: Credentials) -> Future<HTTPStatus> {
        do {
            return try container.client()
                        .post("https://\(credentials.host)/messages?access_token=\(credentials.token)&chat_id=\(chatId)") { (post) in
                            try post.content.encode(msg)
                        }.map{ (resp) in
                            print("msg send response: \(resp.http.body)")
                            return resp.http.status
            }
        } catch {
            return container.eventLoop.future(error: error)
        }
    }

    func udpateFeeds(on container: Container, creds: Credentials) {
        container.withPooledConnection(to: .psql) { (conn) -> EventLoopFuture<Void> in
            Subscription.query(on: conn).all().whenSuccess { (subs) in
                for subscription in subs {
                    if let id = subscription.id {
                        self.updateFeed(id: id, on: conn).whenSuccess{ (entries) in
                            print("entries: \(entries.map { $0.asMessage().text })")
                            for entry in entries {
                                self.send(on: container, chatId: subscription.chatId, msg: entry.asMessage(), credentials: creds)
                                    .whenFailure{ (err) in
                                        print("send error: \(err)");
                                    }
                            }
                        }
                    }
                }
            }
            
            return container.eventLoop.future()
        }.whenComplete {
            print("udpated feeds")
        }
    }
    
    func updateFeed(id: Int, on container: DatabaseConnectable) -> Future<[FeedEntry]> {
        return Subscription
                .find(id, on: container).flatMap{ (sub) -> EventLoopFuture<[FeedEntry]> in
                    if let sub = sub,
                        let url = URL(string: sub.url),
                        let parser = FeedParser(URL: url) {
                        let promise = container.eventLoop.newPromise(of: [FeedEntry].self)
                        parser.parseAsync(result: { (result) in
                            let entries: [FeedEntry]
                            switch result {
                                case let .atom(feed):
                                    entries = (feed.entries ?? []).map{ FeedEntry(with: $0) }
                                case let .rss(feed):
                                    entries = (feed.items ?? []).map{ FeedEntry(with: $0) }
                                case let .json(feed):       // JSON Feed Model
                                    entries = (feed.items ?? []).map{ FeedEntry(with: $0) }
                                case let .failure(error):
                                    promise.fail(error: error)
                                    return
                            }
                            
                            print("\(url): \(entries.count)" )
                            if (entries.count > 0) {
                                container.transaction(on: .psql, { (conn) -> EventLoopFuture<[FeedEntry]> in
                                    return Subscription.find(id, on: conn).flatMap { (sub) -> EventLoopFuture<[FeedEntry]> in
                                        if let sub = sub {
                                            sub.lastUpdated = Date()
                                            var newEntries: [FeedEntry] = []
                                            for entry in entries {
                                                if (entry.date > sub.lastItemSeen) {
                                                    sub.lastItemSeen = entry.date
                                                    newEntries.append(entry)
                                                }
                                            }
                                            return sub.save(on: conn).transform(to: newEntries)
                                        } else {
                                            return conn.eventLoop.future([])
                                        }
                                    }
                                }).whenSuccess(promise.succeed)
                            } else {
                                promise.succeed(result: entries)
                            }
                        })
                        
                        return promise.futureResult
                    } else {
                        return container.future([])
                    }
                }
    }
    
    public func subscribe(_ chatId: Int, to urlString: String, on req: Request) throws -> Future<Subscription> {
        return try req.client().get(urlString).flatMap{ (resp) -> EventLoopFuture<Subscription> in
            if let data = resp.http.body.data,
                let parser = FeedParser(data: data) {
                let promise = req.eventLoop.newPromise(of: Subscription.self)
                parser.parseAsync { (result) in
                    let entries: [FeedEntry]
                    let title: String?
                    
                    switch result {
                    case let .atom(feed):
                        entries = (feed.entries ?? []).map{ FeedEntry(with: $0) }
                        title = feed.title
                    case let .rss(feed):
                        entries = (feed.items ?? []).map{ FeedEntry(with: $0) }
                        title = feed.title
                    case let .json(feed):       // JSON Feed Model
                        entries = (feed.items ?? []).map{ FeedEntry(with: $0) }
                        title = feed.title
                    case let .failure(error):
                        promise.fail(error: error)
                        return
                    }
                    
                    let sub = Subscription(url: urlString, chatId: chatId)
                    sub.title = title
                    for entry in entries {
                        if (entry.date > sub.lastItemSeen) {
                            sub.lastItemSeen = entry.date
                        }
                    }
                    promise.succeed(result: sub)
                }
                
                return promise.futureResult.flatMap{ $0.save(on: req) }
            } else {
                return req.eventLoop.future(error: FeedError.invalidFeed(url: urlString))
            }
        }
    }
    
    
}

final class FeedServiceProvider: Provider {
    let feedService = FeedService()
    
    func register(_ services: inout Services) throws {
        services.register(self.feedService)
    }
    
    func didBoot(_ container: Container) throws -> EventLoopFuture<Void> {
        Jobs.add(interval: .seconds(600)) {
            self.feedService.udpateFeeds(on: container, creds: try! container.make(Credentials.self))
        }
        return container.eventLoop.future()
    }
    

}
