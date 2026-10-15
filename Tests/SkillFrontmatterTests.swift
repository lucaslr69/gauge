import XCTest
@testable import Codenotch

final class SkillFrontmatterTests: XCTestCase {
    func testReadsScalarNameAndDescription() {
        let md = """
        ---
        name: arka-dev
        description: Full-stack development department.
        ---

        # Body
        """
        let (name, description) = SkillFrontmatter.parse(md)
        XCTAssertEqual(name, "arka-dev")
        XCTAssertEqual(description, "Full-stack development department.")
    }

    func testQuotedValuesAreUnwrapped() {
        let md = """
        ---
        name: "arka-dev"
        description: 'Something with: a colon'
        ---
        """
        let (name, description) = SkillFrontmatter.parse(md)
        XCTAssertEqual(name, "arka-dev")
        XCTAssertEqual(description, "Something with: a colon")
    }

    func testFoldedDescriptionJoinsLinesWithSpaces() {
        let md = """
        ---
        name: multi-line
        description: >
          First line of the summary.
          Second line continues.
        ---
        """
        let (name, description) = SkillFrontmatter.parse(md)
        XCTAssertEqual(name, "multi-line")
        XCTAssertEqual(description,
                      "First line of the summary. Second line continues.")
    }

    func testMissingFrontmatterReturnsNil() {
        let md = "# No frontmatter here\nJust prose.\n"
        let (name, description) = SkillFrontmatter.parse(md)
        XCTAssertNil(name)
        XCTAssertNil(description)
    }

    func testHandlesCRLFLineEndings() {
        let md = "---\r\nname: wintry\r\ndescription: ok\r\n---\r\n"
        let (name, description) = SkillFrontmatter.parse(md)
        XCTAssertEqual(name, "wintry")
        XCTAssertEqual(description, "ok")
    }
}
