import XCTest
@testable import QuickPolish2Core

final class ModelsTests: XCTestCase {

    func test_rewriteMode_allCasesCount() {
        XCTAssertEqual(RewriteMode.allCases.count, 3)
    }

    func test_rewriteResult_textForMode_returnsCorrectText() {
        var result = RewriteResult()
        result.results[.natural] = "hey"
        result.results[.professional] = "Dear Sir"
        result.results[.shorter] = "hi"

        XCTAssertEqual(result.text(for: .natural), "hey")
        XCTAssertEqual(result.text(for: .professional), "Dear Sir")
        XCTAssertEqual(result.text(for: .shorter), "hi")
    }

    func test_rewriteResult_textForMode_returnsEmptyWhenMissing() {
        let result = RewriteResult()
        XCTAssertEqual(result.text(for: .natural), "")
    }

    func test_rewriteResult_hasError_falseByDefault() {
        let result = RewriteResult()
        XCTAssertFalse(result.hasError)
    }

    func test_rewriteResult_hasError_trueWhenErrorSet() {
        var result = RewriteResult()
        result.error = "network error"
        XCTAssertTrue(result.hasError)
    }

    func test_previewViewModel_initialStateIsLoading() {
        let vm = PreviewViewModel()
        XCTAssertTrue(vm.isLoading)
        XCTAssertEqual(vm.selectedMode, .natural)
    }

    func test_previewViewModel_currentTextEmptyWhileLoading() {
        let vm = PreviewViewModel()
        XCTAssertEqual(vm.currentText, "")
    }

    func test_previewViewModel_currentTextAfterReady() {
        let vm = PreviewViewModel()
        var result = RewriteResult()
        result.results[.natural] = "hey"
        vm.state = .ready(result)
        XCTAssertEqual(vm.currentText, "hey")
        XCTAssertFalse(vm.isLoading)
    }

    func test_previewViewModel_currentTextChangesWithMode() {
        let vm = PreviewViewModel()
        var result = RewriteResult()
        result.results[.natural] = "hey"
        result.results[.professional] = "Dear"
        vm.state = .ready(result)
        vm.selectedMode = .professional
        XCTAssertEqual(vm.currentText, "Dear")
    }

    func test_previewViewModel_hasError_falseOnNormalResult() {
        let vm = PreviewViewModel()
        vm.state = .ready(RewriteResult())
        XCTAssertFalse(vm.hasError)
    }

    func test_previewViewModel_hasError_trueOnErrorState() {
        let vm = PreviewViewModel()
        vm.state = .error("network failed")
        XCTAssertTrue(vm.hasError)
    }
}
