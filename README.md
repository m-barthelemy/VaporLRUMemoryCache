# VaporLRUMemoryCache

This is a library providing an LRU Cache for Vapor4.

Like the default Memory cache provided by Vapor, it caches content in memory and doesn't have any dependency.

However, VaporLRUMemoryCache has a fixed capacity. When it is reached, least recently accessed items will be deleted. In that sense, this cache is self-maintaining.

The underlying LRU implementation if fairly basic and not optimal; it will probably be improved in the future, but does the job quite well in the meantime.


## Usage

Add the package to your Vapor4 project:
```swift
    dependencies: [
        ...
        .package(url: "https://github.com/m-barthelemy/VaporLRUMemoryCache.git", from: "0.1.0"),
        ...
    ],
    targets: [
        .target(name: "App", dependencies: [
            ...
            "VaporLRUMemoryCache",
            ...
        ]
    ]
    ...
```

Configure Vapor to use `VaporLRUMemoryCache`. This has to be added with the rest of your Vapor4 configuration; usually `configure.swift` :
```swift
...
import VaporLRUMemoryCache

public func configure(_ app: Application) throws {
    ...
    app.caches.use(.memoryLRU(2048))
    ...
}
```

Then, use it! For example, from any Vapor controller:

```swift
func get(req: Request) -> EventLoopFuture<MyStuff> {
    return req.cache.get("mystuff-cache-key", as: MyStuff.self)
        .unwrap(or: Abort(.notFound))
        .map { $0}
}
```



