//
//  CoreDataGatewayTests.swift
//  Eve-Ent
//
//  Created by Nikita Kislyakov on 14.01.2020.
//

import XCTest
import CoreData
import Combine
@testable import CoreDataKit

let testDevices: [Device] = [
    Device(id: 0, name: "iPhone 8"),
    Device(id: 1, name: "iPhone 8 Plus"),
    Device(id: 2, name: "iPhone 11"),
    Device(id: 3, name: "iPhone 11 Pro"),
]

let testUsers: [User] = [
    User(id: 0, firstName: "Makaley", lastName: "Kalkin", devices: .init(arrayLiteral: testDevices[0], testDevices[3])),
    User(id: 1, firstName: "Makaley1", lastName: "Kalkin1", devices: .init(arrayLiteral: testDevices[1])),
    User(id: 2, firstName: "Makaley2", lastName: "Kalkin2", devices: .init(arrayLiteral: testDevices[2])),
]

final class TestCoreDataFactory {
    private var momUrl: URL {
        Bundle(for: TestCoreDataFactory.self).url(forResource: "core-data-kit-test-model", withExtension: "momd")!
    }
    
    private lazy var mom = NSManagedObjectModel(contentsOf: momUrl)!
    
    private lazy var moc = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
    
    private var pc: NSPersistentContainer {
        with(NSPersistentContainer(name: "eve-ent-test-container", managedObjectModel: mom)) {
            let desc = NSPersistentStoreDescription()
            
            desc.type = NSInMemoryStoreType
            desc.shouldAddStoreAsynchronously = false
            
            $0.persistentStoreDescriptions = [desc]
            
            $0.loadPersistentStores { desc, error in
                if let error = error {
                    fatalError(error.localizedDescription)
                }
            }
        }
    }
    
    func makeManagedObjectModel() -> NSManagedObjectModel {
        mom
    }
    
    func makeChildManagedObjectContext() -> NSManagedObjectContext {
        moc
    }
    
    func makePersistentContainer() -> NSPersistentContainer {
        pc
    }
}

class CoreDataGatewayTests: XCTestCase {
    private lazy var coreDataFactory = TestCoreDataFactory()
    
    private var coreData: CoreDataGateway!

    override func setUp() {
        super.setUp()
        
        coreData = .init(
            childContext: coreDataFactory.makeChildManagedObjectContext(),
            container: coreDataFactory.makePersistentContainer()
        )
    }

    override func tearDown() {
        coreData = nil
        
        super.tearDown()
    }
    
    func testSaveOne() {
        waiting("Test save one") { exp in
            self.coreData.save(testUsers[0], shouldEditExisting: true)
                .flatMap {
                    self.coreData.getAll()
                }
                .sink(exp: exp) { (users: [User]) in
                    XCTAssertEqual(users, [testUsers[0]])
                    
                    exp.fulfill()
                }
        }
    }
    
    func testSaveMany() {
        waiting("Test save many") { exp in
            self.coreData.save([testUsers[0]], shouldEditExisting: true)
                .flatMap {
                    self.coreData.getAll()
                }
                .sink(exp: exp) { (users: [User]) in
                    XCTAssertEqual(users, [testUsers[0]])
                    
                    exp.fulfill()
                }
        }
    }
    
    func testEditOne() {
        var editedUser = testUsers[0]
        
        editedUser.firstName = "Nikita"
        editedUser.lastName = "Kislyakov"
        
        waiting("Test edit one") { exp in
            self.coreData.save(testUsers[0], shouldEditExisting: true)
                .flatMap {
                    self.coreData.save(editedUser, shouldEditExisting: true)
                }
                .flatMap {
                    self.coreData.get(byID: editedUser.id)
                }
                .sink(exp: exp) { (user: User?) in
                    XCTAssertEqual(user, editedUser)
                    
                    exp.fulfill()
                }
        }
    }
    
    func testEditMany() {
        var editedUser0 = testUsers[0]
        var editedUser1 = testUsers[1]
        
        editedUser0.firstName = "Nikita"
        editedUser0.lastName = "Kislyakov"
        
        editedUser1.firstName = "Nikita1"
        editedUser1.lastName = "Kisyakov1"
        
        waiting("Test edit many") { exp in
            self.coreData.save([testUsers[0], testUsers[1], testUsers[2]], shouldEditExisting: true)
                .flatMap {
                    self.coreData.save([editedUser0, editedUser1], shouldEditExisting: true)
                }
                .flatMap {
                    self.coreData.getAll()
                }
                .sink(exp: exp) { (users: [User]) in
                    XCTAssertEqual(users.sorted(by: \.id), [editedUser0, editedUser1, testUsers[2]])
                    
                    exp.fulfill()
                }
        }
    }
    
    func testSaveWithoutReplacement() {
        let overwrittenDevices = testDevices.map { Device(id: $0.id, name: $0.name + "!") }
        
        waiting("Test overwrite with replacement") { exp in
            save(testDevices)
                .flatMap {
                    self.save(overwrittenDevices, replace: false)
                }
                .flatMap {
                    self.coreData.getAll()
                }
                .sink(exp: exp) { (devices: [Device]) in
                    XCTAssertNotEqual(devices.sorted(by: \.id), overwrittenDevices)
                    
                    exp.fulfill()
                }
        }
    }


    func testGetAll() {
        waiting("Test get all") { exp in
            save(testUsers)
                .flatMap {
                    self.coreData.getAll()
                }
                .sink(exp: exp) { (users: [User]) in
                    XCTAssertEqual(users.sorted(by: \.id), testUsers.sorted(by: \.id))
                    
                    exp.fulfill()
                }
        }
    }
    
    func testGetByID() {
        waiting("Test get by id") { exp in
            save(testUsers)
                .flatMap {
                    self.coreData.get(byID: testUsers[1].id)
                }
                .sink(exp: exp) { (user: User?) in
                    XCTAssert(user != nil && user!.id == testUsers[1].id)
                    
                    exp.fulfill()
                }
            }
    }
    
    func testGetAllRelated() {
        waiting("Test get all related") { exp in
            save(testDevices)
                .flatMap {
                    self.coreData.getAll()
                }
                .sink(exp: exp) { (devices: [Device]) in
                    XCTAssertEqual(devices.sorted(by: \.id), testDevices)
                    
                    exp.fulfill()
                }
        }
    }
    
    func testGetAllRelatedWithPredicate() {
        waiting("Test get all related with predicate") { exp in
            save(testUsers)
                .flatMap {
                    self.coreData.getAll(using: NSPredicate(format: "user.id == %d", testUsers[0].id))
                }
                .sink(exp: exp) { (devices: [Device]) in
                    XCTAssertEqual(devices.sorted(by: \.id), [testDevices[0], testDevices[3]])
                    
                    exp.fulfill()
                }
        }
    }
    
    func testListenUpdatesByID() {
        let expectedUsers: [User] = [
            User(id: testUsers[0].id, firstName: testUsers[0].firstName, lastName: testUsers[0].lastName, devices: testUsers[0].devices),
            User(id: testUsers[0].id, firstName: testUsers[0].firstName + "!", lastName: testUsers[0].lastName, devices: testUsers[0].devices),
            User(id: testUsers[0].id, firstName: testUsers[0].firstName, lastName: testUsers[0].lastName + "!", devices: testUsers[0].devices),
        ]
        
        waiting("Test listen updates by id") { exp -> AnyCancellable in
            let lock = NSRecursiveLock()
            
            var recordedUsers: [User?] = []

            return coreData
                .save(expectedUsers[0])
                .flatMap {
                    self.coreData.listenUpdates(byID: expectedUsers[0].id)
                }
                .sink(exp: exp) { (user: User?) in
                    lock.lock(); defer { lock.unlock() }
                    
                    recordedUsers.append(user)
                    
                    if recordedUsers.count == expectedUsers.count {
                        XCTAssertEqual(recordedUsers, expectedUsers)
                        
                        exp.fulfill()
                    } else if recordedUsers.count > expectedUsers.count {
                        XCTFail()
                        
                        exp.fulfill()
                    } else {
                        Thread.detachNewThread {
                            let sem = DispatchSemaphore(value: 0)
                            
                            let cancellable = self.coreData
                                .save(expectedUsers[recordedUsers.count])
                                .sink(
                                    receiveCompletion: { _ in sem.signal() },
                                    receiveValue: {}
                                )
                            
                            sem.wait()
                        }
                    }
                }
        }
    }
    
    func testListenUpdatesByIDWhenNotExists() {
        let expectedUsers: [User?] = [
            nil,
            User(id: testUsers[0].id, firstName: testUsers[0].firstName, lastName: testUsers[0].lastName, devices: testUsers[0].devices),
            User(id: testUsers[0].id, firstName: testUsers[0].firstName + "!", lastName: testUsers[0].lastName, devices: testUsers[0].devices),
            User(id: testUsers[0].id, firstName: testUsers[0].firstName, lastName: testUsers[0].lastName + "!", devices: testUsers[0].devices),
        ]
        
        waiting("Test listen updates by id when not exists") { exp -> AnyCancellable in
            let lock = NSRecursiveLock()
            
            var recordedUsers: [User?] = []
            
            return coreData
                .listenUpdates(byID: testUsers[0].id)
                .sink(exp: exp) { (user: User?) in
                    lock.lock(); defer { lock.unlock() }
                    
                    recordedUsers.append(user)
                    
                    if recordedUsers.count == expectedUsers.count {
                        XCTAssertEqual(recordedUsers, expectedUsers)
                        
                        exp.fulfill()
                    } else if recordedUsers.count > expectedUsers.count {
                        XCTFail()
                        
                        exp.fulfill()
                    } else {
                        Thread.detachNewThread {
                            let sem = DispatchSemaphore(value: 0)
                            
                            let cancellable = self.coreData
                                .save(expectedUsers[recordedUsers.count]!)
                                .sink(
                                    receiveCompletion: { _ in sem.signal() },
                                    receiveValue: {}
                                )
                            
                            sem.wait()
                        }
                    }
                }
        }
    }
    
    func testListenAll() {
        var expectedUserArrays: [[User]] = []
        
        for i in 0 ..< testUsers.count {
            expectedUserArrays.append(Array(testUsers[..<i]))
        }
        
        waiting("Test listen all") { exp -> AnyCancellable in
            let lock = NSRecursiveLock()
            
            var recordedUserArrays: [[User]] = []
            
            return coreData
                .listenAll()
                .sink(exp: exp) { (users: [User]) in
                    lock.lock(); defer { lock.unlock() }
                    
                    recordedUserArrays.append(users.sorted(by: \.id))
                    
                    if recordedUserArrays.count == expectedUserArrays.count {
                        XCTAssertEqual(recordedUserArrays, expectedUserArrays)
                        
                        exp.fulfill()
                    } else if recordedUserArrays.count > expectedUserArrays.count {
                        XCTFail()
                        
                        exp.fulfill()
                    } else {
                        Thread.detachNewThread {
                            let sem = DispatchSemaphore(value: 0)
                            
                            let cancellable = self.coreData
                                .save(expectedUserArrays[recordedUserArrays.count])
                                .sink(
                                    receiveCompletion: { _ in sem.signal() },
                                    receiveValue: {}
                                )
                            
                            sem.wait()
                        }
                    }
            }
        }
    }
    
    func testDeleteAll() {
        waiting("Test delete all") { exp in
            save(testUsers)
                .flatMap {
                    self.coreData.deleteAll(ofType: User.self)
                }
                .flatMap {
                    self.coreData.getAll()
                }
                .sink(exp: exp) { (users: [User]) in
                    XCTAssert(users.isEmpty)
                    
                    exp.fulfill()
                }
        }
    }

    private func save<T: NSManagedObjectConvertible>(_ data: [T], replace: Bool = true) -> AnyPublisher<Void, Error> {
        Just((data, replace))
            .setFailureType(to: Error.self)
            .flatMap(coreData.save)
            .map { _ in }
            .eraseToAnyPublisher()
    }
}
