//
//  FeedService.swift
//  App
//
//  Created by Юрий Буянов on 15/01/2019.
//

import Vapor
import FeedKit
import Jobs

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
    
    func send(on worker: Worker, chatId: Int, msg: OutgoingMessage, credentials: Credentials) {
        HTTPClient.connect(scheme: .https,
                          hostname: credentials.host,
                          on: worker).flatMap { (client) -> EventLoopFuture<Void> in
                                let outgoingJson = try! JSONEncoder().encode(msg)
                                let msgRequest = HTTPRequest(method: .POST, url: "/messages?access_token=\(credentials.token)&chat_id=\(chatId)", body: outgoingJson)
                                return client.send(msgRequest).do{ (resp) in
                                            print("msg send response: \(resp.body)")
                                            fflush(stdout)
                                        }.catch { (err) in
                                            print("reply error: \(err)")
                                            fflush(stdout)
                                        }.transform(to: ())
                            }.whenComplete {
                                print("complete")
                            }
        
    }

    func udpateFeeds(on db: DatabaseConnectable, creds: Credentials) {
        Subscription.query(on: db).all().whenSuccess { (subs) in
            for subscription in subs {
                if let id = subscription.id {
                    self.updateFeed(id: id, on: db).whenSuccess{ (entries) in
                        print("entries: \(entries.map { $0.asMessage().text })")
                        for entry in entries {
                            self.send(on: db, chatId: subscription.chatId, msg: entry.asMessage(), credentials: creds)
                        }
                    }
                }
            }
        }
    }
    
    func updateFeed(id: Int, on container: DatabaseConnectable) -> Future<[FeedEntry]> {
        return Subscription
                .find(id, on: container).flatMap{ (sub) -> EventLoopFuture<[FeedEntry]> in
                    if let sub = sub,
                        let url = URL(string: sub.url) {
                        let parser = FeedParser(URL: url)
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
                                                    newEntries += entries
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
}

final class FeedServiceProvider: Provider {
    let feedService = FeedService()
    
    func register(_ services: inout Services) throws {
        services.register(self.feedService)
    }
    
    func didBoot(_ container: Container) throws -> EventLoopFuture<Void> {
        return container.withPooledConnection(to: .psql) { (conn) -> EventLoopFuture<Void> in
            Jobs.add(interval: .seconds(1800)) {
                self.feedService.udpateFeeds(on: conn, creds: try! container.make(Credentials.self))
            }
            return container.eventLoop.future()
        }
    }
    

}
