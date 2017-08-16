import XCTest
import Quick
import Nimble
import RxSwift
import ObjectMapper

@testable import FrequentFlyer

class AuthMethodDataDeserializerSpec: QuickSpec {
    override func spec() {
        describe("AuthMethodDataDeserializer") {
            var subject: AuthMethodDataDeserializer!
            let publishSubject = PublishSubject<AuthMethod>()
            var result: StreamResult<AuthMethod>!
            var authMethods: [AuthMethod] {
                get {
                    return result.elements
                }
            }

            beforeEach {
                subject = AuthMethodDataDeserializer()
            }

            describe("Deserializing auth methods data that is all valid") {
                beforeEach {
                    let validDataJSONArray = [
                        [
                            "type" : "basic",
                            "display_name" : AuthMethod.DisplayNames.basic,
                            "auth_url": "basic_turtle.com"
                        ],
                        [
                            "type" : "oauth",
                            "display_name": AuthMethod.DisplayNames.gitHub,
                            "auth_url": "oauth_turtle.com"
                        ]
                    ]

                    let validData = try! JSONSerialization.data(withJSONObject: validDataJSONArray, options: .prettyPrinted)
                    result = StreamResult(subject.deserialize(validData))
                }

                it("returns an auth method for each JSON auth method entry") {
                    if authMethods.count != 2 {
                        fail("Expected to return 2 auth methods, returned \(authMethods.count)")
                        return
                    }

                    expect(authMethods[0]).to(equal(AuthMethod(type: .basic, displayName: AuthMethod.DisplayNames.basic, url: "basic_turtle.com")))
                    expect(authMethods[1]).to(equal(AuthMethod(type: .gitHub, displayName: AuthMethod.DisplayNames.gitHub, url: "oauth_turtle.com")))
                }

                it("returns no error") {
                    expect(result.error).to(beNil())
                }
            }

            describe("Deserializing auth method data where some of the data is invalid") {
                context("Missing required 'type' field") {
                    beforeEach {
                        let partiallyValidDataJSONArray = [
                            [
                                "type" : "basic",
                                "display_name" : AuthMethod.DisplayNames.basic,
                                "auth_url": "basic_turtle.com"
                            ],
                            [
                                "somethingelse" : "value",
                                "display_name" : AuthMethod.DisplayNames.basic,
                                "auth_url": "basic_crab.com"
                            ]
                        ]

                        let partiallyValidData = try! JSONSerialization.data(withJSONObject: partiallyValidDataJSONArray, options: .prettyPrinted)
                        result = StreamResult(subject.deserialize(partiallyValidData))
                    }

                    it("emits an auth method for each valid JSON auth method entry") {
                        expect(authMethods).to(equal([AuthMethod(type: .basic, displayName: AuthMethod.DisplayNames.basic, url: "basic_turtle.com")]))
                    }

                    it("emits completed") {
                        expect(result.completed).to(beTrue())
                    }
                }

                context("'type' field is not a string") {
                    beforeEach {
                        let partiallyValidDataJSONArray = [
                            [
                                "type" : "basic",
                                "display_name" : AuthMethod.DisplayNames.basic,
                                "auth_url": "basic_turtle.com"
                            ],
                            [
                                "type" : 1,
                                "display_name" : AuthMethod.DisplayNames.basic,
                                "auth_url": "basic_turtle.com"
                            ]
                        ]

                        let partiallyValidData = try! JSONSerialization.data(withJSONObject: partiallyValidDataJSONArray, options: .prettyPrinted)
                        result = StreamResult(subject.deserialize(partiallyValidData))
                    }

                    it("emits an auth method for each valid JSON auth method entry") {
                        expect(authMethods).to(equal([AuthMethod(type: .basic, displayName: AuthMethod.DisplayNames.basic, url: "basic_turtle.com")]))
                    }

                    it("emits completed") {
                        expect(result.completed).to(beTrue())
                    }
                }

                context("Missing required 'display_name' field") {
                    beforeEach {
                        let partiallyValidDataJSONArray = [
                            [
                                "type" : "basic",
                                "display_name" : AuthMethod.DisplayNames.basic
                                ],
                            [
                                "type" : "oauth",
                                "display_name" : AuthMethod.DisplayNames.gitHub,
                                "auth_url": "basic_crab.com"
                            ]
                        ]

                        let partiallyValidData = try! JSONSerialization.data(withJSONObject: partiallyValidDataJSONArray, options: .prettyPrinted)
                        result = StreamResult(subject.deserialize(partiallyValidData))
                    }

                    it("emits an auth method for each valid JSON auth method entry") {
                        expect(authMethods).to(equal([AuthMethod(type: .gitHub, displayName: AuthMethod.DisplayNames.gitHub, url: "basic_crab.com")]))
                    }

                    it("emits completed") {
                        expect(result.completed).to(beTrue())
                    }
                }

                context("'display_name' field is not a string") {
                    beforeEach {
                        let partiallyValidDataJSONArray = [
                            [
                                "type" : "basic",
                                "display_name" : AuthMethod.DisplayNames.basic,
                                "auth_url": "basic_turtle.com"
                            ],
                            [
                                "type" : "oauth",
                                "display_name" : 1,
                                "auth_url": "oauth_turtle.com"
                            ]
                        ]

                        let partiallyValidData = try! JSONSerialization.data(withJSONObject: partiallyValidDataJSONArray, options: .prettyPrinted)
                        result = StreamResult(subject.deserialize(partiallyValidData))
                    }

                    it("emits an auth method for each valid JSON auth method entry") {
                        expect(authMethods).to(equal([AuthMethod(type: .basic, displayName: AuthMethod.DisplayNames.basic, url: "basic_turtle.com")]))
                    }

                    it("emits completed") {
                        expect(result.completed).to(beTrue())
                    }
                }

                context("Unrecognized combination of 'type' and 'display_name'") {
                    beforeEach {
                        let partiallyValidDataJSONArray = [
                            [
                                "type" : "basic",
                                "display_name" : AuthMethod.DisplayNames.basic,
                                "auth_url": "basic_turtle.com"
                            ],
                            [
                                "type" : "basic",
                                "display_name" : "something else",
                                "auth_url": "basic_crab.com"
                            ],
                            [
                                "type" : "oauth",
                                "display_name": AuthMethod.DisplayNames.gitHub,
                                "auth_url": "oauth_turtle.com"
                            ],
                            [
                                "type" : "oauth",
                                "display_name": "something else",
                                "auth_url": "oauth_crab.com"
                            ],
                            [
                                "type" : "oauth",
                                "display_name": AuthMethod.DisplayNames.uaa,
                                "auth_url": "uaa_oauth_turtle.com"
                            ],
                            [
                                "type" : "oauth",
                                "display_name": "something else",
                                "auth_url": "oauth_crab.com"
                            ]
                        ]

                        let partiallyValidData = try! JSONSerialization.data(withJSONObject: partiallyValidDataJSONArray, options: .prettyPrinted)
                        result = StreamResult(subject.deserialize(partiallyValidData))
                    }

                    it("emits an auth method for each valid JSON auth method entry") {
                        let expectedAuthMethods = [
                            AuthMethod(type: .basic, displayName: AuthMethod.DisplayNames.basic, url: "basic_turtle.com"),
                            AuthMethod(type: .gitHub, displayName: AuthMethod.DisplayNames.gitHub, url: "oauth_turtle.com"),
                            AuthMethod(type: .uaa, displayName: AuthMethod.DisplayNames.uaa, url: "uaa_oauth_turtle.com"),
                        ]

                        expect(authMethods).to(equal(expectedAuthMethods))
                    }

                    it("emits completed") {
                        expect(result.completed).to(beTrue())
                    }
                }

                context("Missing required 'auth_url' field") {
                    beforeEach {
                        let partiallyValidDataJSONArray = [
                            [
                                "type" : "basic",
                                "display_name" : AuthMethod.DisplayNames.basic
                            ],
                            [
                                "type" : "oauth",
                                "display_name" : AuthMethod.DisplayNames.gitHub,
                                "auth_url": "basic_crab.com"
                            ]
                        ]

                        let partiallyValidData = try! JSONSerialization.data(withJSONObject: partiallyValidDataJSONArray, options: .prettyPrinted)
                        result = StreamResult(subject.deserialize(partiallyValidData))
                    }

                    it("emits an auth method for each valid JSON auth method entry") {
                        expect(authMethods).to(equal([AuthMethod(type: .gitHub, displayName: AuthMethod.DisplayNames.gitHub, url: "basic_crab.com")]))
                    }

                    it("emits completed") {
                        expect(result.completed).to(beTrue())
                    }
                }

                context("'auth_url' field is not a string") {
                    beforeEach {
                        let partiallyValidDataJSONArray = [
                            [
                                "type" : "basic",
                                "display_name" : AuthMethod.DisplayNames.basic,
                                "auth_url": "basic_turtle.com"
                            ],
                            [
                                "type" : "basic",
                                "display_name" : AuthMethod.DisplayNames.basic,
                                "auth_url": 1
                            ]
                        ]

                        let partiallyValidData = try! JSONSerialization.data(withJSONObject: partiallyValidDataJSONArray, options: .prettyPrinted)
                        result = StreamResult(subject.deserialize(partiallyValidData))
                    }

                    it("emits an auth method for each valid JSON auth method entry") {
                        expect(authMethods).to(equal([AuthMethod(type: .basic, displayName: AuthMethod.DisplayNames.basic, url: "basic_turtle.com")]))
                    }

                    it("emits completed") {
                        expect(result.completed).to(beTrue())
                    }
                }
            }

            describe("Given data cannot be interpreted as JSON") {
                beforeEach {
                    let authMethodsDataString = "some string"

                    let invalidAuthMethodsData = authMethodsDataString.data(using: String.Encoding.utf8)
                    result = StreamResult(subject.deserialize(invalidAuthMethodsData!))
                }

                it("emits no methods") {
                    expect(authMethods).to(haveCount(0))
                }

                it("emits an error") {
                    let error = result.error as? MapError
                    expect(error).toNot(beNil())
                    expect(error?.reason).to(equal("Could not interpret response from auth methods endpoint as JSON"))
                }
            }
        }
    }
}
