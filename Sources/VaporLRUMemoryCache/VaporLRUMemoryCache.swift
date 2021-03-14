// Basic implementation of LRU, inspired by https://marcosantadev.com/implement-cache-lru-swift/

import Foundation
import Vapor

final class LruCacheStorage<Key: Hashable, Value> {
    
    private struct CachePayload {
        let key: Key
        let value: Value?
    }
    
    private let capacity: Int
    private let list = DoublyLinkedList<CachePayload>()
    private var nodesDict = [Key: DoublyLinkedListNode<CachePayload>]()
    private var lock: Lock
    
    init(capacity: Int = 1000) {
        self.capacity = max(0, capacity)
        self.lock = .init()
    }
    
    func set<T>(_ key: String, to value: T?) where T: Encodable {
        self.lock.lock()
        defer { self.lock.unlock() }
        let payload = CachePayload(key: key as! Key, value: value as? Value)
        
        if let node = self.nodesDict[key as! Key] {
            node.payload = payload
            self.list.moveToHead(node)
        } else {
            let node = self.list.addHead(payload)
            self.nodesDict[key as! Key] = node
        }
        if self.list.count > self.capacity {
            let nodeRemoved = self.list.removeLast()
            if let key = nodeRemoved?.payload.key {
                self.nodesDict[key] = nil
            }
        }
    }
    
    func get<T>(_ key: String) -> T? where T: Decodable {
        self.lock.lock()
        defer { self.lock.unlock() }
        
        let node: DoublyLinkedListNode<CachePayload>? = self.nodesDict[key as! Key]
        if(node != nil) {
            self.list.moveToHead(node!)
        }
        return node?.payload.value as? T
    }
}
 
 
private struct LRUCache: Cache {
    let storage: LruCacheStorage<String, Any>
    let eventLoop: EventLoop
    
    init(storage: LruCacheStorage<String, Any>, on eventLoop: EventLoop) {
        self.storage = storage
        self.eventLoop = eventLoop
    }
    
    func get<T>(_ key: String, as type: T.Type) -> EventLoopFuture<T?> where T: Decodable
    {
        self.eventLoop.makeSucceededFuture(self.storage.get(key))
    }
    
    func set<T>(_ key: String, to value: T?) -> EventLoopFuture<Void> where T: Encodable
    {
        self.storage.set(key, to: value)
        return self.eventLoop.makeSucceededFuture(())
    }
    
    func `for`(_ request: Request) -> LRUCache {
        .init(storage: self.storage, on: request.eventLoop)
    }
}
 

extension Application.Caches {
    
    /// In-memory cache. Thread safe.
    /// Not shared between multiple instances of your application.
    /// When the number of stored items reaches `capacity`, least recently used items will be removed.
    public func memoryLRU(_ capacity: Int) -> Cache {
        LRUCache(storage: self.memoryStorage(capacity), on: self.application.eventLoopGroup.next())
    }
    
    private func memoryStorage(_ capacity: Int) -> LruCacheStorage<String, Any> {
        let lock = self.application.locks.lock(for: MemoryCacheKey.self)
        lock.lock()
        defer { lock.unlock() }
        if let existing = self.application.storage.get(MemoryCacheKey.self) {
            return existing
        } else {
            let new = LruCacheStorage<String, Any>(capacity: capacity)
            self.application.storage.set(MemoryCacheKey.self, to: new)
            return new
        }
    }
}

extension Application.Caches.Provider {
    /// In-memory cache. Thread safe.
    /// Not shared between multiple instances of your application.
    /// When the number of stored items reaches 1000, least recently used items will be removed.
    public static var memoryLRU: Self {
        .init {
            $0.caches.use { $0.caches.memoryLRU(1000) }
        }
    }
    
    /// In-memory cache. Thread safe.
    /// Not shared between multiple instances of your application.
    /// When the number of stored items reaches `capacity`, least recently used items will be removed.
    public static func memoryLRU(_ capacity: Int) -> Self {
        .init {
            $0.caches.use { $0.caches.memoryLRU(capacity) }
        }
    }
}

private struct MemoryCacheKey: LockKey, StorageKey {
    typealias Value = LruCacheStorage<String, Any>
}


typealias DoublyLinkedListNode<T> = DoublyLinkedList<T>.Node<T>

final class DoublyLinkedList<T> {
    final class Node<T> {
        var payload: T
        weak var previous: Node<T>?
        weak var next: Node<T>?
        
        init(payload: T) {
            self.payload = payload
        }
    }
    
    private(set) var count: Int = 0
    private var head: Node<T>?
    private var tail: Node<T>?
    
    func addHead(_ payload: T) -> Node<T> {
        let node = Node(payload: payload)
        defer {
            head = node
            count += 1
        }
        
        guard let head = head else {
            tail = node
            return node
        }
        
        head.previous = node
        node.previous = nil
        node.next = head
        
        return node
    }
    
    func moveToHead(_ node: Node<T>) {
        guard node !== head else { return }
        let previous = node.previous
        let next = node.next
        
        previous?.next = next
        next?.previous = previous
        
        node.next = head
        node.previous = nil
        
        if node === tail {
            tail = previous
        }
        
        self.head = node
    }
    
    func removeLast() -> Node<T>? {
        guard let tail = self.tail else { return nil }
        
        let previous = tail.previous
        previous?.next = nil
        self.tail = previous
        
        if count == 1 {
            head = nil
        }
        count -= 1
        
        return tail
    }
}
