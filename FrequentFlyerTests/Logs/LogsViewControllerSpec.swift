import XCTest
import Quick
import Nimble
import Fleet

@testable import FrequentFlyer
import EventSource

class LogsViewControllerSpec: QuickSpec {
    override func spec() {
        class MockSSEService: SSEService {
            var capturedTarget: Target?
            var capturedBuild: Build?
            var returnedConnection: MockSSEConnection?

            override func openSSEConnection(target: Target, build: Build) -> SSEConnection {
                capturedTarget = target
                capturedBuild = build
                returnedConnection = MockSSEConnection()
                return returnedConnection!
            }
        }

        class MockSSEConnection: SSEConnection {
            init() {
                let eventSource = EventSource(url: "somethingwithnoprotocol.com")
                let sseEventParser = SSEMessageEventParser()

                super.init(eventSource: eventSource, sseEventParser: sseEventParser)
            }
        }

        class MockLogsStylingParser: LogsStylingParser {
            private var toReturnMap = [String : String]()

            func mockStripStylingCoding(when input: String, thenReturn toReturn: String) {
                toReturnMap[input] = toReturn
            }

            override func stripStylingCoding(originalString: String) -> String {
                if let string = toReturnMap[originalString] {
                    return string
                }

                return ""
            }
        }

        class MockKeychainWrapper: KeychainWrapper {
            var didCallDelete = false

            override func deleteTarget() {
                didCallDelete = true
            }
        }

        describe("LogsViewController") {
            var subject: LogsViewController!
            var mockSSEService: MockSSEService!
            var mockLogsStylingParser: MockLogsStylingParser!
            var mockKeychainWrapper: MockKeychainWrapper!

            var mockConcourseEntryViewController: ConcourseEntryViewController!

            beforeEach {
                let storyboard = UIStoryboard(name: "Main", bundle: nil)

                mockConcourseEntryViewController = try! storyboard.mockIdentifier(ConcourseEntryViewController.storyboardIdentifier, usingMockFor: ConcourseEntryViewController.self)

                subject = storyboard.instantiateViewController(withIdentifier: LogsViewController.storyboardIdentifier) as! LogsViewController

                mockSSEService = MockSSEService()
                subject.sseService = mockSSEService

                mockLogsStylingParser = MockLogsStylingParser()
                subject.logsStylingParser = mockLogsStylingParser

                mockKeychainWrapper = MockKeychainWrapper()
                subject.keychainWrapper = mockKeychainWrapper

                subject.target = try! Factory.createTarget()
            }

            describe("After the view has loaded") {
                beforeEach {
                    let _ = Fleet.setInAppWindowRootNavigation(subject)
                }

                describe("When initialized without a build") {
                    describe("When requested to fetch logs") {
                        beforeEach {
                            subject.fetchLogs()
                        }

                        it("makes no network call") {
                            expect(mockSSEService.capturedTarget).toEventually(beNil())
                            expect(mockSSEService.capturedBuild).toEventually(beNil())
                        }

                        it("displays nothing in the logs") {
                            expect(subject.logOutputView?.text).toEventually(equal(""))
                        }
                    }
                }

                describe("When initialized with a build") {
                    beforeEach {
                        subject.build = BuildBuilder().withName("LogsViewControllerBuild").build()
                    }

                    describe("When requested to fetch logs") {
                        beforeEach {
                            subject.fetchLogs()
                        }

                        it("asks the logs service to begin collecting logs") {
                            let expectedTarget = try! Factory.createTarget()
                            let expectedBuild = BuildBuilder().withName("LogsViewControllerBuild").build()
                            expect(mockSSEService.capturedTarget).to(equal(expectedTarget))
                            expect(mockSSEService.capturedBuild).to(equal(expectedBuild))
                        }

                        it("starts a loading indicator") {
                            expect(subject.loadingIndicator?.isAnimating).to(beTrue())
                        }

                        describe("When the connection reports logs") {
                            beforeEach {
                                guard let logsCallback = mockSSEService.returnedConnection?.onLogsReceived else {
                                    fail("Failed to set a callback for received logs on the SSE connection")
                                    return
                                }

                                let turtleLogEvent = LogEvent(payload: "turtle log entry")
                                let crabLogEvent = LogEvent(payload: "crab log entry")

                                mockLogsStylingParser.mockStripStylingCoding(when: "turtle log entry", thenReturn: "parsed turtle log entry")
                                mockLogsStylingParser.mockStripStylingCoding(when: "crab log entry", thenReturn: "parsed crab log entry")

                                let logs = [turtleLogEvent, crabLogEvent]
                                logsCallback(logs)
                            }

                            it("appends the logs to the log view") {
                                expect(subject.logOutputView?.text).toEventually(contain("parsed turtle log entry"))
                                expect(subject.logOutputView?.text).toEventually(contain("parsed crab log entry"))
                            }

                            it("stops any active loading indicator") {
                                expect(subject.loadingIndicator?.isAnimating).toEventually(beFalse())
                            }
                        }

                        describe("When the connection errors for any reason") {
                            beforeEach {
                                guard let errorCallback = mockSSEService.returnedConnection?.onError else {
                                    fail("Failed to set a callback for errors on the SSE connection")
                                    return
                                }

                                errorCallback(NSError(domain: "", code: -1, userInfo: nil))
                            }

                            it("stops any active loading indicator") {
                                expect(subject.loadingIndicator?.isAnimating).toEventually(beFalse())
                                expect(subject.loadingIndicator?.isHidden).toEventually(beTrue())
                            }

                            it("presents an alert describing the authorization error") {
                                let alert: () -> UIAlertController? = {
                                    return Fleet.getApplicationScreen()?.topmostViewController as? UIAlertController
                                }

                                expect(alert()).toEventuallyNot(beNil())
                                expect(alert()?.title).toEventually(equal("Unauthorized"))
                                expect(alert()?.message).toEventually(equal("Your credentials have expired. Please authenticate again."))
                            }

                            describe("Tapping the 'Log Out' button on the alert") {
                                it("pops itself back to the initial page") {
                                    let screen = Fleet.getApplicationScreen()
                                    var didTapLogOut = false
                                    let assertLogOutTappedBehavior = { () -> Bool in
                                        if didTapLogOut {
                                            return screen?.topmostViewController === mockConcourseEntryViewController
                                        }

                                        if let alert = screen?.topmostViewController as? UIAlertController {
                                            alert.tapAlertAction(withTitle: "Log Out")
                                            didTapLogOut = true
                                        }

                                        return false
                                    }

                                    expect(assertLogOutTappedBehavior()).toEventually(beTrue())
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
