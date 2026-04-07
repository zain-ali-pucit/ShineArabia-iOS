import Foundation

// MARK: - LocalCacheService
// Persists API responses to JSON files in the app's Caches directory.
// Strategy: load from cache instantly on first render, then silently refresh
// from the server in the background and update only if data has changed.

class LocalCacheService {
    static let shared = LocalCacheService()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = .sortedKeys   // deterministic output for change detection
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    private let cacheDir: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = caches.appendingPathComponent("ShineArabiaCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private init() {}

    // MARK: - Private helpers

    private func url(for key: String) -> URL {
        cacheDir.appendingPathComponent("\(key).json")
    }

    private func write<T: Encodable>(_ value: T, key: String) {
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url(for: key), options: .atomic)
    }

    private func read<T: Decodable>(key: String) -> T? {
        guard let data = try? Data(contentsOf: url(for: key)) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    /// Returns true if `newValue` encodes differently from what is currently stored.
    /// Uses the same encoder (sortedKeys) so byte comparison is reliable.
    private func isDifferent<T: Encodable>(_ newValue: T, fromKey key: String) -> Bool {
        guard let newData  = try? encoder.encode(newValue),
              let existing = try? Data(contentsOf: url(for: key)) else { return true }
        return newData != existing
    }

    // MARK: - Categories

    func saveCategories(_ categories: [APICategory]) {
        write(categories, key: "categories")
    }

    func loadCategories() -> [APICategory]? {
        read(key: "categories")
    }

    /// Returns true (and saves) only when server data differs from cache.
    @discardableResult
    func updateCategoriesIfChanged(_ categories: [APICategory]) -> Bool {
        guard isDifferent(categories, fromKey: "categories") else { return false }
        saveCategories(categories)
        return true
    }

    // MARK: - Packages (keyed by category slug)

    func savePackages(_ packages: [APIPackage], slug: String) {
        write(packages, key: "packages_\(slug)")
    }

    func loadPackages(slug: String) -> [APIPackage]? {
        read(key: "packages_\(slug)")
    }

    @discardableResult
    func updatePackagesIfChanged(_ packages: [APIPackage], slug: String) -> Bool {
        let key = "packages_\(slug)"
        guard isDifferent(packages, fromKey: key) else { return false }
        write(packages, key: key)
        return true
    }

    // MARK: - Bundles

    func saveBundles(_ bundles: [APIBundle]) {
        write(bundles, key: "bundles")
    }

    func loadBundles() -> [APIBundle]? {
        read(key: "bundles")
    }

    @discardableResult
    func updateBundlesIfChanged(_ bundles: [APIBundle]) -> Bool {
        guard isDifferent(bundles, fromKey: "bundles") else { return false }
        saveBundles(bundles)
        return true
    }

    // MARK: - Popular Items

    func savePopularItems(_ items: [APIPopularItem]) {
        write(items, key: "popular_items")
    }

    func loadPopularItems() -> [APIPopularItem]? {
        read(key: "popular_items")
    }

    @discardableResult
    func updatePopularItemsIfChanged(_ items: [APIPopularItem]) -> Bool {
        guard isDifferent(items, fromKey: "popular_items") else { return false }
        savePopularItems(items)
        return true
    }
}
