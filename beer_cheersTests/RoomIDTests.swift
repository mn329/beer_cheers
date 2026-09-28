//
//  RoomIDTests.swift
//  beer_cheersTests
//

import Testing
@testable import beer_cheers

struct RoomIDTests {
    @Test func trimsSurroundingWhitespace() throws {
        #expect(try RoomID.normalize("  飲み会  ") == "飲み会")
    }

    @Test(arguments: ["", "   ", "a/b", "a.b", "a#b", "a$b", "a[b", "a]b", "a\nb"])
    func rejectsNamesFirebaseCannotUseAsKey(name: String) {
        #expect(throws: RoomRepositoryError.self) {
            try RoomID.normalize(name)
        }
    }

    @Test func acceptsNameAtMaxLength() throws {
        let name = String(repeating: "a", count: RoomID.maxLength)
        #expect(try RoomID.normalize(name) == name)
    }

    @Test func rejectsNameOverMaxLength() {
        let name = String(repeating: "a", count: RoomID.maxLength + 1)
        #expect(throws: RoomRepositoryError.self) {
            try RoomID.normalize(name)
        }
    }
}
