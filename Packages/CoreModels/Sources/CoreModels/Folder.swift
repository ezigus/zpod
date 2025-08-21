public struct Folder: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public var name: String
    public var parentId: String?
    // Add other properties as needed

    public init(id: String, name: String, parentId: String? = nil) {
        self.id = id
        self.name = name
        self.parentId = parentId
    }
}
