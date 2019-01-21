import Vapor

/// Register your application's routes here.
public func routes(_ router: Router) throws {
    // Basic "It works" example
    router.get { req in
        return "It works!"
    }
    
    // Basic "Hello, world!" example
    router.get("hello") { req in
        return "Hello, world!"
    }

    let cmdController = CmdController()
    router.post("tt_callback", use: cmdController.handleMessage)
    router.get("subscriptions", use: cmdController.listSubscriptions)
}
