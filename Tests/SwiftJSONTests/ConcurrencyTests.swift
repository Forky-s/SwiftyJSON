//  ConcurrencyTests.swift
//
//  Copyright (c) 2014 - 2017 Ruoyu Fu, Pinglin Tang
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import XCTest
import SwiftyJSON

class ConcurrencyTests: XCTestCase {

    // MARK: - Test 1: Actor Boundary Passing

    actor DataProcessor {
        func process(_ json: JSON) -> String {
            return json["name"].stringValue
        }

        func processDictionary(_ json: JSON) -> Int {
            return json["count"].intValue
        }

        func processArray(_ json: JSON) -> Int {
            return json[0].intValue
        }
    }

    func testActorBoundaryPassing() async {
        let json = JSON(["name": "Test"])
        let processor = DataProcessor()
        let result = await processor.process(json)
        XCTAssertEqual(result, "Test")
    }

    func testActorBoundaryPassingWithDictionary() async {
        let json = JSON(["count": 42, "status": "active"])
        let processor = DataProcessor()
        let result = await processor.processDictionary(json)
        XCTAssertEqual(result, 42)
    }

    func testActorBoundaryPassingWithArray() async {
        let json = JSON([100, 200, 300])
        let processor = DataProcessor()
        let result = await processor.processArray(json)
        XCTAssertEqual(result, 100)
    }

    // MARK: - Test 2: Sendable Closure and Task

    func testSendableClosureWithTask() async {
        let json = JSON(["value": "Hello"])
        let task = Task { @Sendable () -> String in
            return json["value"].stringValue
        }
        let result = await task.value
        XCTAssertEqual(result, "Hello")
    }

    func testSendableClosureWithComplexData() async {
        let json = JSON([
            "user": ["name": "Alice", "age": 30],
            "active": true
        ])
        let task = Task { @Sendable () -> String in
            return json["user"]["name"].stringValue
        }
        let result = await task.value
        XCTAssertEqual(result, "Alice")
    }

    // MARK: - Test 3: Async JSON Parsing

    func testAsyncJSONParsing() async throws {
        let jsonString = "{\"status\":\"ok\"}"
        let data = jsonString.data(using: .utf8)!

        let task = Task {
            return try JSON(data: data)
        }

        let json = try await task.value
        let status = json["status"].stringValue
        XCTAssertEqual(status, "ok")
    }

    func testAsyncJSONParsingWithComplexData() async throws {
        let jsonString = "{\"results\": [{\"id\": 1, \"name\": \"Item1\"}, {\"id\": 2, \"name\": \"Item2\"}]}"
        let data = jsonString.data(using: .utf8)!

        let task = Task {
            return try JSON(data: data)
        }

        let json = try await task.value
        XCTAssertEqual(json["results"].arrayValue.count, 2)
        XCTAssertEqual(json["results"][0]["name"].stringValue, "Item1")
    }

    // MARK: - Test 4: Concurrent Read Access with TaskGroup

    func testConcurrentReadAccess() async {
        let json = JSON(["values": [1, 2, 3, 4, 5]])

        await withTaskGroup(of: Int.self) { group in
            for i in 0..<5 {
                group.addTask {
                    return json["values"][i].intValue
                }
            }

            var sum = 0
            for await value in group {
                sum += value
            }
            XCTAssertEqual(sum, 15)
        }
    }

    func testConcurrentReadAccessWithDictionary() async {
        let json = JSON([
            "items": [
                ["id": 1, "value": 10],
                ["id": 2, "value": 20],
                ["id": 3, "value": 30]
            ]
        ])

        await withTaskGroup(of: Int.self) { group in
            for i in 0..<3 {
                group.addTask {
                    return json["items"][i]["value"].intValue
                }
            }

            var sum = 0
            for await value in group {
                sum += value
            }
            XCTAssertEqual(sum, 60)
        }
    }

    // MARK: - Test 5: MainActor Isolation

    @MainActor
    func mainActorFunction(_ json: JSON) -> String {
        return json["title"].stringValue
    }

    func testMainActorIsolation() async {
        let json = JSON(["title": "Main Thread Task"])
        let result = await mainActorFunction(json)
        XCTAssertEqual(result, "Main Thread Task")
    }

    // MARK: - Test 6: Task.detached Isolation

    func testTaskDetachedIsolation() async {
        let json = JSON(["data": "detached"])

        let task = Task.detached { @Sendable () -> String in
            return json["data"].stringValue
        }

        let result = await task.value
        XCTAssertEqual(result, "detached")
    }

    // MARK: - Test 7: Complex Nested JSON

    func testComplexNestedJSONConcurrency() async {
        let json = JSON([
            "users": [
                [
                    "id": 1,
                    "name": "Alice",
                    "posts": [
                        ["id": 101, "title": "Post 1"],
                        ["id": 102, "title": "Post 2"]
                    ]
                ],
                [
                    "id": 2,
                    "name": "Bob",
                    "posts": [
                        ["id": 201, "title": "Post 3"]
                    ]
                ]
            ]
        ])

        await withTaskGroup(of: (Int, String).self) { group in
            for i in 0..<2 {
                group.addTask {
                    let userId = json["users"][i]["id"].intValue
                    let userName = json["users"][i]["name"].stringValue
                    return (userId, userName)
                }
            }

            var names: [String] = []
            for await (_, name) in group {
                names.append(name)
            }

            XCTAssert(names.contains("Alice"))
            XCTAssert(names.contains("Bob"))
        }
    }

    func testComplexNestedJSONAccess() async {
        let json = JSON([
            [
                ["deep": [1, 2, 3]],
                ["deep": [4, 5, 6]]
            ],
            [
                ["deep": [7, 8, 9]],
                ["deep": [10, 11, 12]]
            ]
        ])

        let task = Task { @Sendable () -> Int in
            return json[0][1]["deep"][2].intValue
        }

        let result = await task.value
        XCTAssertEqual(result, 6)
    }

    // MARK: - Test 8: All JSON Types in Concurrent Context

    func testAllJSONTypesInConcurrency() async {
        let json = JSON([
            "string": "value",
            "number": 42,
            "bool": true,
            "null": NSNull(),
            "array": [1, 2, 3],
            "dictionary": ["nested": "object"]
        ])

        await withTaskGroup(of: String.self) { group in
            group.addTask {
                return json["string"].stringValue
            }
            group.addTask {
                return String(json["number"].intValue)
            }
            group.addTask {
                return String(json["bool"].boolValue)
            }
            group.addTask {
                return json["null"].type == .null ? "null" : "not_null"
            }
            group.addTask {
                return String(json["array"].arrayValue.count)
            }
            group.addTask {
                return json["dictionary"]["nested"].stringValue
            }

            var results: [String] = []
            for await result in group {
                results.append(result)
            }

            XCTAssertEqual(results.count, 6)
            XCTAssert(results.contains("value"))
            XCTAssert(results.contains("42"))
            XCTAssert(results.contains("true"))
            XCTAssert(results.contains("null"))
            XCTAssert(results.contains("3"))
            XCTAssert(results.contains("object"))
        }
    }

    // MARK: - Test 9: Error Handling Across Actor Boundaries

    actor ErrorProcessor {
        func processJSON(_ json: JSON) throws -> String {
            guard json["required"].exists() else {
                throw SwiftyJSONError.notExist
            }
            return json["required"].stringValue
        }

        func processWithTypeError(_ json: JSON) throws -> Int {
            guard json["count"].type == .number else {
                throw SwiftyJSONError.wrongType
            }
            return json["count"].intValue
        }
    }

    func testErrorHandlingAcrossActorBoundaries() async {
        let json = JSON(["other": "value"])
        let processor = ErrorProcessor()

        do {
            _ = try await processor.processJSON(json)
            XCTFail("Should have thrown notExist error")
        } catch SwiftyJSONError.notExist {
            // Expected behavior
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testErrorHandlingWithWrongType() async {
        let json = JSON(["count": "not_a_number"])
        let processor = ErrorProcessor()

        do {
            _ = try await processor.processWithTypeError(json)
            XCTFail("Should have thrown wrongType error")
        } catch SwiftyJSONError.wrongType {
            // Expected behavior
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testSuccessfulErrorHandling() async {
        let json = JSON(["required": "present", "count": 123])
        let processor = ErrorProcessor()

        do {
            let result = try await processor.processJSON(json)
            XCTAssertEqual(result, "present")

            let count = try await processor.processWithTypeError(json)
            XCTAssertEqual(count, 123)
        } catch {
            XCTFail("Should not have thrown error: \(error)")
        }
    }

    // MARK: - Test 10: Mixed Async Operations

    func testMixedAsyncOperations() async throws {
        let jsonString = "{\"users\": [{\"id\": 1, \"name\": \"User1\"}, {\"id\": 2, \"name\": \"User2\"}]}"
        let data = jsonString.data(using: .utf8)!

        let parseTask = Task {
            return try JSON(data: data)
        }

        let json = try await parseTask.value

        let names = await withTaskGroup(of: String.self) { group in
            for i in 0..<2 {
                group.addTask {
                    return json["users"][i]["name"].stringValue
                }
            }

            var result: [String] = []
            for await name in group {
                result.append(name)
            }
            return result
        }

        XCTAssertEqual(names.count, 2)
        XCTAssert(names.contains("User1"))
        XCTAssert(names.contains("User2"))
    }
}
