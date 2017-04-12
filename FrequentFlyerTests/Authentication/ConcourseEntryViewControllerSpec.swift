import XCTest
import Quick
import Nimble
import Fleet
import RxSwift
@testable import FrequentFlyer

class ConcourseEntryViewControllerSpec: QuickSpec {
    class MockAuthMethodsService: AuthMethodsService {
        var capturedTeamName: String?
        var capturedConcourseURL: String?
        var authMethodsSubject = PublishSubject<AuthMethod>()

        override func getMethods(forTeamName teamName: String, concourseURL: String) -> Observable<AuthMethod> {
            capturedTeamName = teamName
            capturedConcourseURL = concourseURL
            return authMethodsSubject
        }
    }

    class MockUnauthenticatedTokenService: UnauthenticatedTokenService {
        var capturedTeamName: String?
        var capturedConcourseURL: String?
        var tokenSubject = PublishSubject<Token>()

        override func getUnauthenticatedToken(forTeamName teamName: String, concourseURL: String) -> Observable<Token> {
            capturedTeamName = teamName
            capturedConcourseURL = concourseURL
            return tokenSubject
        }
    }

    override func spec() {
        describe("ConcourseEntryViewController") {
            var subject: ConcourseEntryViewController!
            var mockAuthMethodsService: MockAuthMethodsService!
            var mockUnauthenticatedTokenService: MockUnauthenticatedTokenService!
            var mockUserTextInputPageOperator: UserTextInputPageOperator!

            var mockLoginViewController: LoginViewController!
            var mockGitHubAuthViewController: GitHubAuthViewController!
            var mockTeamPipelinesViewController: TeamPipelinesViewController!

            beforeEach {
                let storyboard = UIStoryboard(name: "Main", bundle: nil)

                mockLoginViewController = try! storyboard.mockIdentifier(LoginViewController.storyboardIdentifier, usingMockFor: LoginViewController.self)
                mockGitHubAuthViewController = try! storyboard.mockIdentifier(GitHubAuthViewController.storyboardIdentifier, usingMockFor: GitHubAuthViewController.self)
                mockTeamPipelinesViewController = try! storyboard.mockIdentifier(TeamPipelinesViewController.storyboardIdentifier, usingMockFor: TeamPipelinesViewController.self)

                subject = storyboard.instantiateViewController(withIdentifier: ConcourseEntryViewController.storyboardIdentifier) as! ConcourseEntryViewController

                mockAuthMethodsService = MockAuthMethodsService()
                subject.authMethodsService = mockAuthMethodsService

                mockUnauthenticatedTokenService = MockUnauthenticatedTokenService()
                subject.unauthenticatedTokenService = mockUnauthenticatedTokenService

                mockUserTextInputPageOperator = UserTextInputPageOperator()
                subject.userTextInputPageOperator = mockUserTextInputPageOperator
            }

            describe("After the view loads") {
                var navigationController: UINavigationController!

                beforeEach {
                    navigationController = UINavigationController(rootViewController: subject)
                    Fleet.setAsAppWindowRoot(navigationController)
                }

                it("sets a blank title") {
                    expect(subject.title).to(equal(""))
                }

                it("sets up its Concourse URL entry text field") {
                    guard let concourseURLEntryTextField = subject.concourseURLEntryField else {
                        fail("Failed to create Concourse URL entry text field")
                        return
                    }

                    expect(concourseURLEntryTextField.textField?.autocorrectionType).to(equal(UITextAutocorrectionType.no))
                    expect(concourseURLEntryTextField.textField?.keyboardType).to(equal(UIKeyboardType.URL))
                }

                it("sets itself as the UserTextInputPageOperator's delegate") {
                    expect(mockUserTextInputPageOperator.delegate).to(beIdenticalTo(subject))
                }

                describe("As a UserTextInputPageDelegate") {
                    it("returns text fields") {
                        expect(subject.textFields.count).to(equal(1))
                        expect(subject.textFields[0]).to(beIdenticalTo(subject?.concourseURLEntryField?.textField))
                    }

                    it("returns a page view") {
                        expect(subject.pageView).to(beIdenticalTo(subject.view))
                    }

                    it("returns a page scrolls view") {
                        expect(subject.pageScrollView).to(beIdenticalTo(subject.scrollView))
                    }
                }

                describe("Availability of the 'Submit' button") {
                    it("is disabled just after the view is loaded") {
                        expect(subject.submitButton?.isEnabled).to(beFalse())
                    }

                    describe("When the 'Concourse URL' field has text") {
                        beforeEach {
                            try! subject.concourseURLEntryField?.textField?.enter(text: "turtle url")
                        }

                        it("enables the button") {
                            expect(subject.submitButton!.isEnabled).to(beTrue())
                        }

                        describe("When the 'Concourse URL' field is cleared") {
                            beforeEach {
                                try! subject.concourseURLEntryField?.textField?.startEditing()
                                try! subject.concourseURLEntryField?.textField?.backspaceAll()
                                try! subject.concourseURLEntryField?.textField?.stopEditing()
                            }

                            it("disables the button") {
                                expect(subject.submitButton!.isEnabled).to(beFalse())
                            }
                        }
                    }
                }

                func returnAuthMethods(_ methods: [AuthMethod]) {
                    let methodSubject = mockAuthMethodsService.authMethodsSubject
                    for method in methods { methodSubject.onNext(method) }
                    methodSubject.onCompleted()
                }

                describe("Entering a Concourse URL without 'http://' or 'https://' and hitting 'Submit'") {
                    beforeEach {
                        try! subject.concourseURLEntryField?.textField?.enter(text: "partial-concourse.com")

                        try! subject.submitButton?.tap()
                    }

                    it("prepends your request with `https://` and submits") {
                        expect(mockAuthMethodsService.capturedTeamName).to(equal("main"))
                        expect(mockAuthMethodsService.capturedConcourseURL).to(equal("https://partial-concourse.com"))
                    }

                    it("disables the button") {
                        expect(subject.submitButton?.isEnabled).toEventually(beFalse())
                    }

                    it("makes a call to the auth methods service using the input team and Concourse URL") {
                        expect(mockAuthMethodsService.capturedTeamName).to(equal("main"))
                        expect(mockAuthMethodsService.capturedConcourseURL).to(equal("https://partial-concourse.com"))
                    }

                    describe("When the auth methods service call resolves with some auth methods and no error") {
                        beforeEach {
                            let basicAuthMethod = AuthMethod(type: .basic, url: "basic-auth.com")
                            let gitHubAuthMethod = AuthMethod(type: .gitHub, url: "gitHub-auth.com")
                            returnAuthMethods([basicAuthMethod, gitHubAuthMethod])
                        }

                        it("presents a LoginViewController") {
                            expect(Fleet.getApplicationScreen()?.topmostViewController).toEventually(beIdenticalTo(mockLoginViewController))
                        }

                        it("sets the fetched auth methods on the view controller") {
                            expect(mockLoginViewController.authMethods).toEventually(equal([
                                AuthMethod(type: .basic, url: "basic-auth.com"),
                                AuthMethod(type: .gitHub, url: "gitHub-auth.com")
                                ]))
                        }

                        it("sets the entered Concourse URL on the view controller") {
                            expect(mockLoginViewController.concourseURLString).toEventually(equal("https://partial-concourse.com"))
                        }
                    }

                    describe("When the auth methods service call resolves only with GitHub authentication") {
                        beforeEach {
                            let gitHubAuthMethod = AuthMethod(type: .gitHub, url: "gitHub-auth.com")
                            returnAuthMethods([gitHubAuthMethod])
                        }

                        it("presents a GitHubAuthViewController") {
                            expect(Fleet.getApplicationScreen()?.topmostViewController).toEventually(beIdenticalTo(mockGitHubAuthViewController))
                        }

                        it("sets the entered Concourse URL on the view controller") {
                            expect(mockGitHubAuthViewController.concourseURLString).toEventually(equal("https://partial-concourse.com"))
                        }

                        it("sets the auth method's auth URL on the view controller") {
                            expect(mockGitHubAuthViewController.gitHubAuthURLString).toEventually(equal("gitHub-auth.com"))
                        }
                    }

                    describe("When the auth methods service call resolves with no auth methods and no error") {
                        beforeEach {
                            returnAuthMethods([])
                        }

                        it("makes a call to the token auth service using the input team, Concourse URL, and no other credentials") {
                            expect(mockUnauthenticatedTokenService.capturedTeamName).to(equal("main"))
                            expect(mockUnauthenticatedTokenService.capturedConcourseURL).to(equal("https://partial-concourse.com"))
                        }

                        describe("When the token auth service call resolves with a valid token") {
                            beforeEach {
                                let token = Token(value: "turtle auth token")
                                mockUnauthenticatedTokenService.tokenSubject.onNext(token)
                            }

                            it("replaces itself with the TeamPipelinesViewController") {
                                expect(Fleet.getApplicationScreen()?.topmostViewController).toEventually(beIdenticalTo(mockTeamPipelinesViewController))
                            }

                            it("creates a new target from the entered information and view controller") {
                                let expectedTarget = Target(name: "target", api: "https://partial-concourse.com",
                                                            teamName: "main", token: Token(value: "turtle auth token")
                                )
                                expect(mockTeamPipelinesViewController.target).toEventually(equal(expectedTarget))
                            }
                        }

                        describe("When the token auth service call resolves with some error") {
                            beforeEach {
                                let error = BasicError(details: "error details")
                                mockUnauthenticatedTokenService.tokenSubject.onError(error)
                            }

                            it("presents an alert that contains the error message from the token auth service") {
                                expect(subject.presentedViewController).toEventually(beAKindOf(UIAlertController.self))

                                let screen = Fleet.getApplicationScreen()
                                expect(screen?.topmostViewController).toEventually(beAKindOf(UIAlertController.self))

                                let alert = screen?.topmostViewController as? UIAlertController
                                expect(alert?.title).toEventually(equal("Authorization Failed"))
                                expect(alert?.message).toEventually(equal("error details"))
                            }

                            it("enables the button") {
                                expect(subject.submitButton?.isEnabled).toEventually(beTrue())
                            }
                        }
                    }
                }

                describe("Entering a valid Concourse URL and hitting 'Submit'") {
                    beforeEach {
                        try! subject.concourseURLEntryField?.textField?.enter(text: "https://concourse.com")

                        try! subject.submitButton?.tap()
                    }

                    it("disables the button") {
                        expect(subject.submitButton?.isEnabled).toEventually(beFalse())
                    }

                    it("makes a call to the auth methods service using the input team and Concourse URL") {
                        expect(mockAuthMethodsService.capturedTeamName).to(equal("main"))
                        expect(mockAuthMethodsService.capturedConcourseURL).to(equal("https://concourse.com"))
                    }

                    describe("When the auth methods service call resolves with some auth methods and no error") {
                        beforeEach {
                            let basicAuthMethod = AuthMethod(type: .basic, url: "basic-auth.com")
                            let gitHubAuthMethod = AuthMethod(type: .gitHub, url: "gitHub-auth.com")
                            returnAuthMethods([basicAuthMethod, gitHubAuthMethod])
                        }

                        it("presents a LoginViewController") {
                            expect(Fleet.getApplicationScreen()?.topmostViewController).toEventually(beIdenticalTo(mockLoginViewController))
                        }

                        it("sets the fetched auth methods on the view controller") {
                            expect(mockLoginViewController.authMethods).toEventually(equal([
                                AuthMethod(type: .basic, url: "basic-auth.com"),
                                AuthMethod(type: .gitHub, url: "gitHub-auth.com")
                                ]))
                        }

                        it("sets the entered Concourse URL on the view controller") {
                            expect(mockLoginViewController.concourseURLString).toEventually(equal("https://concourse.com"))
                        }
                    }

                    describe("When the auth methods service call resolves only with GitHub authentication") {
                        beforeEach {
                            let gitHubAuthMethod = AuthMethod(type: .gitHub, url: "gitHub-auth.com")
                            returnAuthMethods([gitHubAuthMethod])
                        }

                        it("presents a GitHubAuthViewController") {
                            expect(Fleet.getApplicationScreen()?.topmostViewController).toEventually(beIdenticalTo(mockGitHubAuthViewController))
                        }

                        it("sets the entered Concourse URL on the view controller") {
                            expect(mockGitHubAuthViewController.concourseURLString).toEventually(equal("https://concourse.com"))
                        }

                        it("sets the auth method's auth URL on the view controller") {
                            expect(mockGitHubAuthViewController.gitHubAuthURLString).toEventually(equal("gitHub-auth.com"))
                        }
                    }

                    describe("When the auth methods service call resolves with no auth methods and no error") {
                        beforeEach {
                            returnAuthMethods([])
                        }

                        it("makes a call to the token auth service using the input team, Concourse URL, and no other credentials") {
                            expect(mockUnauthenticatedTokenService.capturedTeamName).to(equal("main"))
                            expect(mockUnauthenticatedTokenService.capturedConcourseURL).to(equal("https://concourse.com"))
                        }

                        describe("When the token auth service call resolves with a valid token") {
                            beforeEach {
                                let token = Token(value: "turtle auth token")
                                mockUnauthenticatedTokenService.tokenSubject.onNext(token)
                            }

                            it("replaces itself with the TeamPipelinesViewController") {
                                expect(Fleet.getApplicationScreen()?.topmostViewController).toEventually(beIdenticalTo(mockTeamPipelinesViewController))
                            }

                            it("creates a new target from the entered information and view controller") {
                                let expectedTarget = Target(name: "target", api: "https://concourse.com",
                                                            teamName: "main", token: Token(value: "turtle auth token")
                                )
                                expect(mockTeamPipelinesViewController.target).toEventually(equal(expectedTarget))
                            }
                        }

                        describe("When the token auth service call resolves with some error") {
                            beforeEach {
                                let error = BasicError(details: "error details")
                                mockUnauthenticatedTokenService.tokenSubject.onError(error)
                            }

                            it("presents an alert that contains the error message from the token auth service") {
                                expect(subject.presentedViewController).toEventually(beAKindOf(UIAlertController.self))

                                let screen = Fleet.getApplicationScreen()
                                expect(screen?.topmostViewController).toEventually(beAKindOf(UIAlertController.self))

                                let alert = screen?.topmostViewController as? UIAlertController
                                expect(alert?.title).toEventually(equal("Authorization Failed"))
                                expect(alert?.message).toEventually(equal("error details"))
                            }

                            it("enables the button") {
                                expect(subject.submitButton?.isEnabled).toEventually(beTrue())
                            }
                        }
                    }
                }
            }
        }
    }
}
