import XCTest
import CoreFoundation
@testable import TestSupport
import CoreModels

final class ComprehensiveInMemoryFolderManagerTests: XCTestCase {
    private var folderManager: InMemoryFolderManager!
    
    override func setUp() async throws {
        folderManager = InMemoryFolderManager()
    }
    
    override func tearDown() async throws {
        folderManager = nil
    }
    
    // MARK: - Basic CRUD Operations
    
    func testAdd_ValidFolder() throws {
        // Given: A valid folder
        let folder = MockFolder.createSample(id: "test-1", name: "Test Folder")
        
        // When: Adding the folder
        try folderManager.add(folder)
        
        // Then: Should be able to find it
        let found = folderManager.find(id: "test-1")
        XCTAssertEqual(found?.id, "test-1")
        XCTAssertEqual(found?.name, "Test Folder")
        XCTAssertNil(found?.parentId)
    }
    
    func testAdd_DuplicateId() {
        // Given: A folder already in the manager
        let original = MockFolder.createSample(id: "duplicate", name: "Original")
        try! folderManager.add(original)
        
        // When: Adding another folder with the same ID
        let duplicate = MockFolder.createSample(id: "duplicate", name: "Duplicate")
        
        // Then: Should throw duplicate error
        XCTAssertThrowsError(try folderManager.add(duplicate)) { error in
            if case TestSupportError.duplicateId(let message) = error {
                XCTAssertTrue(message.contains("duplicate"))
            } else {
                XCTFail("Expected duplicateId error, got \(error)")
            }
        }
    }
    
    func testAdd_InvalidParent() {
        // Given: A folder with non-existent parent
        let folder = MockFolder.createChild(id: "child", name: "Child", parentId: "non-existent")
        
        // When: Adding the folder
        // Then: Should throw invalid parent error
        XCTAssertThrowsError(try folderManager.add(folder)) { error in
            if case TestSupportError.invalidParent(let message) = error {
                XCTAssertTrue(message.contains("non-existent"))
            } else {
                XCTFail("Expected invalidParent error, got \(error)")
            }
        }
    }
    
    func testUpdate_ExistingFolder() throws {
        // Given: A folder in the manager
        let original = MockFolder.createSample(id: "update-test", name: "Original Name")
        try folderManager.add(original)
        
        // When: Updating the folder
        let updated = Folder(id: "update-test", name: "Updated Name", parentId: nil)
        try folderManager.update(updated)
        
        // Then: Should reflect the update
        let found = folderManager.find(id: "update-test")
        XCTAssertEqual(found?.name, "Updated Name")
    }
    
    func testUpdate_NonExistentFolder() {
        // Given: A non-existent folder
        let folder = MockFolder.createSample(id: "non-existent", name: "Test")
        
        // When: Updating the non-existent folder
        // Then: Should throw not found error
        XCTAssertThrowsError(try folderManager.update(folder)) { error in
            if case TestSupportError.notFound(let message) = error {
                XCTAssertTrue(message.contains("non-existent"))
            } else {
                XCTFail("Expected notFound error, got \(error)")
            }
        }
    }
    
    func testRemove_ExistingFolder() throws {
        // Given: A folder in the manager
        let folder = MockFolder.createSample(id: "remove-test", name: "To Remove")
        try folderManager.add(folder)
        XCTAssertNotNil(folderManager.find(id: "remove-test"))
        
        // When: Removing the folder
        try folderManager.remove(id: "remove-test")
        
        // Then: Should no longer be found
        XCTAssertNil(folderManager.find(id: "remove-test"))
    }
    
    func testRemove_NonExistentFolder() {
        // Given: An empty manager
        // When: Removing a non-existent folder
        // Then: Should throw not found error
        XCTAssertThrowsError(try folderManager.remove(id: "non-existent")) { error in
            if case TestSupportError.notFound(let message) = error {
                XCTAssertTrue(message.contains("non-existent"))
            } else {
                XCTFail("Expected notFound error, got \(error)")
            }
        }
    }
    
    func testRemove_FolderWithChildren() throws {
        // Given: A parent folder with a child
        let parent = MockFolder.createRoot(id: "parent", name: "Parent")
        let child = MockFolder.createChild(id: "child", name: "Child", parentId: "parent")
        
        try folderManager.add(parent)
        try folderManager.add(child)
        
        // When: Trying to remove parent with children
        // Then: Should throw has children error
        XCTAssertThrowsError(try folderManager.remove(id: "parent")) { error in
            if case TestSupportError.hasChildren(let message) = error {
                XCTAssertTrue(message.contains("parent"))
            } else {
                XCTFail("Expected hasChildren error, got \(error)")
            }
        }
    }
    
    // MARK: - Hierarchy Operations
    
    func testGetChildren_NoChildren() throws {
        // Given: A folder with no children
        let parent = MockFolder.createRoot(id: "parent", name: "Parent")
        try folderManager.add(parent)
        
        // When: Getting children
        let children = folderManager.getChildren(of: "parent")
        
        // Then: Should return empty array
        XCTAssertTrue(children.isEmpty)
    }
    
    func testGetChildren_MultipleChildren() throws {
        // Given: A parent with multiple children
        let parent = MockFolder.createRoot(id: "parent", name: "Parent")
        let child1 = MockFolder.createChild(id: "child1", name: "Child 1", parentId: "parent")
        let child2 = MockFolder.createChild(id: "child2", name: "Child 2", parentId: "parent")
        let unrelated = MockFolder.createRoot(id: "unrelated", name: "Unrelated")
        
        try folderManager.add(parent)
        try folderManager.add(child1)
        try folderManager.add(child2)
        try folderManager.add(unrelated)
        
        // When: Getting children of parent
        let children = folderManager.getChildren(of: "parent")
        
        // Then: Should return only direct children
        XCTAssertEqual(children.count, 2)
        let childIds = Set(children.map(\.id))
        XCTAssertTrue(childIds.contains("child1"))
        XCTAssertTrue(childIds.contains("child2"))
        XCTAssertFalse(childIds.contains("unrelated"))
    }
    
    func testGetDescendants_DeepHierarchy() throws {
        // Given: A deep folder hierarchy
        let root = MockFolder.createRoot(id: "root", name: "Root")
        let level1 = MockFolder.createChild(id: "level1", name: "Level 1", parentId: "root")
        let level2a = MockFolder.createChild(id: "level2a", name: "Level 2A", parentId: "level1")
        let level2b = MockFolder.createChild(id: "level2b", name: "Level 2B", parentId: "level1")
        let level3 = MockFolder.createChild(id: "level3", name: "Level 3", parentId: "level2a")
        
        try folderManager.add(root)
        try folderManager.add(level1)
        try folderManager.add(level2a)
        try folderManager.add(level2b)
        try folderManager.add(level3)
        
        // When: Getting descendants of root
        let descendants = folderManager.getDescendants(of: "root")
        
        // Then: Should return all descendants
        XCTAssertEqual(descendants.count, 4)
        let descendantIds = Set(descendants.map(\.id))
        XCTAssertTrue(descendantIds.contains("level1"))
        XCTAssertTrue(descendantIds.contains("level2a"))
        XCTAssertTrue(descendantIds.contains("level2b"))
        XCTAssertTrue(descendantIds.contains("level3"))
    }
    
    func testGetDescendants_EmptyHierarchy() throws {
        // Given: A leaf folder with no children
        let leaf = MockFolder.createRoot(id: "leaf", name: "Leaf")
        try folderManager.add(leaf)
        
        // When: Getting descendants
        let descendants = folderManager.getDescendants(of: "leaf")
        
        // Then: Should return empty array
        XCTAssertTrue(descendants.isEmpty)
    }
    
    func testGetRootFolders_Mixed() throws {
        // Given: Mix of root and child folders
        let root1 = MockFolder.createRoot(id: "root1", name: "Root 1")
        let root2 = MockFolder.createRoot(id: "root2", name: "Root 2")
        let child = MockFolder.createChild(id: "child", name: "Child", parentId: "root1")
        
        try folderManager.add(root1)
        try folderManager.add(root2)
        try folderManager.add(child)
        
        // When: Getting root folders
        let roots = folderManager.getRootFolders()
        
        // Then: Should return only root folders
        XCTAssertEqual(roots.count, 2)
        let rootIds = Set(roots.map(\.id))
        XCTAssertTrue(rootIds.contains("root1"))
        XCTAssertTrue(rootIds.contains("root2"))
        XCTAssertFalse(rootIds.contains("child"))
    }
    
    func testGetRootFolders_OnlyChildren() throws {
        // Given: Only child folders (no roots)
        let parent = MockFolder.createRoot(id: "parent", name: "Parent")
        let child = MockFolder.createChild(id: "child", name: "Child", parentId: "parent")
        
        try folderManager.add(parent)
        try folderManager.add(child)
        
        // When: Getting root folders
        let roots = folderManager.getRootFolders()
        
        // Then: Should return only the parent
        XCTAssertEqual(roots.count, 1)
        XCTAssertEqual(roots.first?.id, "parent")
    }
    
    // MARK: - Initialization
    
    func testInitialization_WithInitialFolders() throws {
        // Given: Initial folders for initialization
        let folder1 = MockFolder.createRoot(id: "init-1", name: "Initial 1")
        let folder2 = MockFolder.createRoot(id: "init-2", name: "Initial 2")
        let initialFolders = [folder1, folder2]
        
        // When: Creating manager with initial folders
        let manager = InMemoryFolderManager(initial: initialFolders)
        
        // Then: Should contain the initial folders
        XCTAssertEqual(manager.all().count, 2)
        XCTAssertNotNil(manager.find(id: "init-1"))
        XCTAssertNotNil(manager.find(id: "init-2"))
    }
    
    func testInitialization_EmptyInitial() {
        // Given: Empty initial array
        // When: Creating manager with empty initial
        let manager = InMemoryFolderManager(initial: [])
        
        // Then: Should be empty
        XCTAssertTrue(manager.all().isEmpty)
    }
    
    // MARK: - Complex Scenarios
    
    func testCompleteHierarchyOperations() throws {
        // Given: Building a complete hierarchy
        let root = MockFolder.createRoot(id: "companies", name: "Tech Companies")
        let apple = MockFolder.createChild(id: "apple", name: "Apple", parentId: "companies")
        let microsoft = MockFolder.createChild(id: "microsoft", name: "Microsoft", parentId: "companies")
        let wwdc = MockFolder.createChild(id: "wwdc", name: "WWDC", parentId: "apple")
        
        try folderManager.add(root)
        try folderManager.add(apple)
        try folderManager.add(microsoft)
        try folderManager.add(wwdc)
        
        // When: Performing various hierarchy operations
        let appleChildren = folderManager.getChildren(of: "apple")
        let companiesDescendants = folderManager.getDescendants(of: "companies")
        let rootFolders = folderManager.getRootFolders()
        
        // Then: Should correctly handle hierarchy
        XCTAssertEqual(appleChildren.count, 1)
        XCTAssertEqual(appleChildren.first?.id, "wwdc")
        
        XCTAssertEqual(companiesDescendants.count, 3)
        let descendantIds = Set(companiesDescendants.map(\.id))
        XCTAssertTrue(descendantIds.contains("apple"))
        XCTAssertTrue(descendantIds.contains("microsoft"))
        XCTAssertTrue(descendantIds.contains("wwdc"))
        
        XCTAssertEqual(rootFolders.count, 1)
        XCTAssertEqual(rootFolders.first?.id, "companies")
    }
    
    // MARK: - Unicode and Edge Cases
    
    func testUnicodeSupport() throws {
        // Given: A folder with Unicode content
        let unicodeFolder = MockFolder.createUnicode()
        
        // When: Adding and retrieving the folder
        try folderManager.add(unicodeFolder)
        let found = folderManager.find(id: "folder-unicode")
        
        // Then: Should preserve Unicode content
        XCTAssertEqual(found?.name, "📁 Pasta Especial")
    }
    
    func testErrorLocalization() {
        // Given: Various error scenarios
        let errors: [TestSupportError] = [
            .duplicateId("Test duplicate"),
            .notFound("Test not found"),
            .invalidParent("Test invalid parent"),
            .hasChildren("Test has children")
        ]
        
        // When: Getting error descriptions
        for error in errors {
            let description = error.localizedDescription
            
            // Then: Should have proper localized descriptions
            XCTAssertFalse(description.isEmpty)
            switch error {
            case .duplicateId:
                XCTAssertTrue(description.contains("Duplicate ID"))
            case .notFound:
                XCTAssertTrue(description.contains("Not Found"))
            case .invalidParent:
                XCTAssertTrue(description.contains("Invalid Parent"))
            case .hasChildren:
                XCTAssertTrue(description.contains("Has Children"))
            }
        }
    }
    
    func testLargeHierarchy_Performance() throws {
        // Given: A large folder hierarchy
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Create root folder
        let root = MockFolder.createRoot(id: "perf-root", name: "Performance Root")
        try folderManager.add(root)
        
        // Create 100 child folders
        for i in 0..<100 {
            let child = MockFolder.createChild(id: "perf-child-\(i)", name: "Child \(i)", parentId: "perf-root")
            try folderManager.add(child)
        }
        
        let addTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // When: Performing operations
        let searchStartTime = CFAbsoluteTimeGetCurrent()
        let children = folderManager.getChildren(of: "perf-root")
        let descendants = folderManager.getDescendants(of: "perf-root")
        let searchTime = CFAbsoluteTimeGetCurrent() - searchStartTime
        
        // Then: Should complete operations in reasonable time
        XCTAssertEqual(children.count, 100)
        XCTAssertEqual(descendants.count, 100)
        XCTAssertLessThan(addTime, 1.0, "Adding 100 folders should take less than 1 second")
        XCTAssertLessThan(searchTime, 0.1, "Hierarchy operations should take less than 0.1 seconds")
    }
    
    func testSendableCompliance() {
        // Given: TestSupportError should be Sendable
        let error: TestSupportError = .duplicateId("Test")
        
        // When: Using in async context (compilation test)
        let sendableError: any Error & Sendable = error
        
        // Then: Should compile without warnings
        XCTAssertNotNil(sendableError)
    }
}