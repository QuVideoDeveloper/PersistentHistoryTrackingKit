//
//  FetcherTests.swift
//
//
//  Created by Yang Xu on 2022/2/11
//  Copyright © 2022 Yang Xu. All rights reserved.
//
//  Follow me on Twitter: @fatbobman
//  My Blog: https://www.fatbobman.com
//  微信公共号: 肘子的Swift记事本
//

import CoreData
@testable import PersistentHistoryTrackingKit
import XCTest

class FetcherTest: XCTestCase {
    let storeURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)
        .first?
        .appendingPathComponent("PersistentHistoryKitFetcherTest.sqlite") ?? URL(fileURLWithPath: "")

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: storeURL)
        try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal"))
        try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm"))
    }

    /// 使用两个协调器，模拟在app group的情况下，从不同的app或app extension中操作数据库。
    func testFetcherInAppGroup() async throws {
        // given
        let container1 = CoreDataHelper.createNSPersistentContainer(storeURL: storeURL)
        let container2 = CoreDataHelper.createNSPersistentContainer(storeURL: storeURL)
        let app1backgroundContext = container1.newBackgroundContext()
        let fetcher = PersistentHistoryTrackingFetcher(backgroundContext: app1backgroundContext,
                                                    currentAuthor: AppActor.app1.rawValue,
                                                    allAuthors: [AppActor.app1.rawValue, AppActor.app2.rawValue])

        let app1viewContext = container1.viewContext
        app1viewContext.transactionAuthor = AppActor.app1.rawValue

        let app2viewContext = container2.viewContext
        app2viewContext.transactionAuthor = AppActor.app2.rawValue

        // when
        app1viewContext.performAndWait {
            let event = Event(context: app1viewContext)
            event.timestamp = Date()
            app1viewContext.saveIfChanged()
        }

        app2viewContext.performAndWait {
            let event = Event(context: app2viewContext)
            event.timestamp = Date()
            app2viewContext.saveIfChanged()
        }

        // then
        let transactions = try fetcher.fetchTransactions(from: Date().addingTimeInterval(-2))
        XCTAssertEqual(transactions.count, 1)

        let request = NSFetchRequest<NSNumber>(entityName: "Event")
        let eventCounts = try app1viewContext.count(for: request)
        XCTAssertEqual(eventCounts, 2)
    }

    func testFetcherInBatchOperation() async throws {
        guard #available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *) else {
            return
        }
        // given
        let container = CoreDataHelper.createNSPersistentContainer(storeURL: storeURL)
        let viewContext = container.viewContext
        let batchContext = container.newBackgroundContext()
        let backgroundContext = container.newBackgroundContext()

        viewContext.transactionAuthor = AppActor.app1.rawValue
        batchContext.transactionAuthor = AppActor.app2.rawValue // 批量添加使用单独的author

        let fetcher = PersistentHistoryTrackingFetcher(backgroundContext: backgroundContext,
                                                    currentAuthor: AppActor.app1.rawValue,
                                                    allAuthors: [AppActor.app1.rawValue, AppActor.app2.rawValue])

        // when insert by batch
        viewContext.performAndWait {
            let event = Event(context: viewContext)
            event.timestamp = Date()
            viewContext.saveIfChanged()
        }

        try batchContext.performAndWait {
            var count = 0

            let batchInsert = NSBatchInsertRequest(entity: Event.entity()) { (dictionary: NSMutableDictionary) in
                dictionary["timestamp"] = Date()
                count += 1
                return count == 10
            }
            try batchContext.execute(batchInsert)
        }

        // then
        let transactions = try fetcher.fetchTransactions(from: Date().addingTimeInterval(-2))
        XCTAssertEqual(transactions.count, 1)
        XCTAssertEqual(transactions.first?.changes?.count, 9)

        let request = NSFetchRequest<NSNumber>(entityName: "Event")
        let eventCounts = try viewContext.count(for: request)
        XCTAssertEqual(eventCounts, 10)
    }
}