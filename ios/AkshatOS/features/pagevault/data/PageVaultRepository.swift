import Foundation
import SwiftData

@MainActor protocol PageVaultRepository {
    func load() throws -> PageVaultLibrary
    func save(_ book: PageVaultBook) throws
    func delete(id: UUID) throws
}

@MainActor final class SwiftDataPageVaultRepository: PageVaultRepository {
    private var container: ModelContainer?

    init(container: ModelContainer? = nil) { self.container = container }

    private func context() throws -> ModelContext {
        if container == nil {
            let schema = Schema(versionedSchema: PageVaultSchemaV1.self)
            container = try ModelContainer(for: schema, migrationPlan: PageVaultMigration.self,
                configurations: [ModelConfiguration("PageVault", schema: schema)])
        }
        return container!.mainContext
    }

    func load() throws -> PageVaultLibrary {
        let rows = try context().fetch(FetchDescriptor<PageVaultSchemaV1.SavedBook>())
        let books = try rows.map { try JSONDecoder().decode(PageVaultBook.self, from: $0.payload) }
        guard Set(books.map(\.id)).count == books.count,
              Set(books.map(\.fingerprint)).count == books.count,
              zip(rows, books).allSatisfy({ $0.0.id == $0.1.id }) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return PageVaultLibrary(books: books)
    }

    func save(_ book: PageVaultBook) throws {
        let context = try context()
        do {
            let payload = try JSONEncoder().encode(book)
            let rows = try context.fetch(FetchDescriptor<PageVaultSchemaV1.SavedBook>())
            if let row = rows.first(where: { $0.id == book.id }) { row.payload = payload }
            else { context.insert(try PageVaultSchemaV1.SavedBook(book)) }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func delete(id: UUID) throws {
        let context = try context()
        do {
            for row in try context.fetch(FetchDescriptor<PageVaultSchemaV1.SavedBook>()) where row.id == id {
                context.delete(row)
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
