import Foundation

public struct Folder: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public var name: String
    public var parentId: String?
    public let dateCreated: Date

    public init(id: String, name: String, parentId: String? = nil, dateCreated: Date = Date()) {
        self.id = id
        self.name = name
        self.parentId = parentId
        self.dateCreated = dateCreated
    }

    public var isRoot: Bool {
        return parentId == nil
    }
}
