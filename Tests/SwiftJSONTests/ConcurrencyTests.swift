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

/// Tests verifying Sendable conformance for Swift 6 concurrency.
/// Each test targets a specific type made Sendable in this PR.
class ConcurrencyTests: XCTestCase {

    actor Processor {
        func extract(_ json: JSON) -> String {
            json["name"].stringValue
        }

        func extractType(_ json: JSON) -> Type {
            json["value"].type
        }

        func requireField(_ json: JSON) throws -> String {
            guard json["required"].exists() else {
                throw SwiftyJSONError.notExist
            }
            return json["required"].stringValue
        }
    }

    /// Verifies JSON conforms to Sendable (can cross actor boundary)
    func testJSONSendable() async {
        let json = JSON(["name": "test", "count": 42])
        let processor = Processor()

        let result = await processor.extract(json)

        XCTAssertEqual(result, "test")
    }

    /// Verifies Type enum conforms to Sendable (can be returned across actor boundary)
    func testTypeSendable() async {
        let processor = Processor()

        let stringType = await processor.extractType(JSON(["value": "hello"]))
        let numberType = await processor.extractType(JSON(["value": 123]))
        let boolType = await processor.extractType(JSON(["value": true]))
        let nullType = await processor.extractType(JSON(["value": NSNull()]))
        let arrayType = await processor.extractType(JSON(["value": [1, 2, 3]]))
        let dictType = await processor.extractType(JSON(["value": ["nested": "object"]]))

        XCTAssertEqual(stringType, .string)
        XCTAssertEqual(numberType, .number)
        XCTAssertEqual(boolType, .bool)
        XCTAssertEqual(nullType, .null)
        XCTAssertEqual(arrayType, .array)
        XCTAssertEqual(dictType, .dictionary)
    }

    /// Verifies SwiftyJSONError conforms to Sendable (can be thrown across actor boundary)
    func testSwiftyJSONErrorSendable() async {
        let processor = Processor()

        do {
            _ = try await processor.requireField(JSON(["other": "value"]))
            XCTFail("Should have thrown")
        } catch SwiftyJSONError.notExist {
            // Error successfully crossed actor boundary
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
