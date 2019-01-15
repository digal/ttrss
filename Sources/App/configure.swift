import FluentPostgreSQL
import Vapor

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    /// Register providers first
    try services.register(FluentPostgreSQLProvider(enableIdentityColumns: true))
    try services.register(CredentialsProvider(token: Environment.get("RSS_TT_TOKEN")!))


    /// Register routes to the router
    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)

    /// Register middleware
    var middlewares = MiddlewareConfig() // Create _empty_ middleware config
    /// middlewares.use(FileMiddleware.self) // Serves files from `Public/` directory
    middlewares.use(ErrorMiddleware.self) // Catches errors and converts to HTTP response
    services.register(middlewares)

    // Configure a SQLite database
    let dbUrl = Environment.get("DATABASE_URL") ?? ""
    let dbConfig = PostgreSQLDatabaseConfig(url: dbUrl)!
    let postgre = PostgreSQLDatabase(config: dbConfig)

    /// Register the configured SQLite database to the database config.
    var databases = DatabasesConfig()
    databases.add(database: postgre, as: .psql)
    services.register(databases)
    
    var migrations = MigrationConfig()
    migrations.add(model: Subscription.self, database: .psql)
    services.register(migrations)

}
