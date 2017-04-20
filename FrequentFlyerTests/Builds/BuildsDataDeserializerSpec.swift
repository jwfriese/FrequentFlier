import XCTest
import Quick
import Nimble
import SwiftyJSON
import RxSwift

@testable import FrequentFlyer

class BuildsDataDeserializerSpec: QuickSpec {
    class MockBuildDataDeserializer: BuildDataDeserializer {
        private var toReturnBuild: [Data : Build] = [:]
        private var toReturnError: [Data : DeserializationError] = [:]

        fileprivate func when(_ data: JSON, thenReturn build: Build) {
            let jsonData = try! data.rawData(options: .prettyPrinted)
            toReturnBuild[jsonData] = build
        }

        fileprivate func when(_ data: JSON, thenErrorWith error: DeserializationError) {
            let jsonData = try! data.rawData(options: .prettyPrinted)
            toReturnError[jsonData] = error
        }
        
        override func deserialize(_ data: Data) -> ReplaySubject<Build> {
            let subject = ReplaySubject<Build>.createUnbounded()
            if let error = toReturnError[data] {
                subject.onError(error)
            } else {
                if let token = toReturnBuild[data] {
                    subject.onNext(token)
                }
                subject.onCompleted()
            }
            return subject
        }
    }

    override func spec() {
        fdescribe("BuildsDataDeserializer") {
            var subject: BuildsDataDeserializer!
            var mockBuildDataDeserializer: MockBuildDataDeserializer!

            var validBuildJSONOne: JSON!
            var validBuildJSONTwo: JSON!
            var validBuildJSONThree: JSON!
            var result: StreamResult<[Build]>!

            beforeEach {
                subject = BuildsDataDeserializer()

                mockBuildDataDeserializer = MockBuildDataDeserializer()
                subject.buildDataDeserializer = mockBuildDataDeserializer

                validBuildJSONOne = JSON(dictionaryLiteral: [
                    ("id", 1),
                    ("name", "name"),
                    ("team_name", "team name"),
                    ("status", "status 1"),
                    ("job_name", "crab job name"),
                    ("pipeline_name", "crab pipeline name")
                ])

                validBuildJSONTwo = JSON(dictionaryLiteral: [
                    ("id", 2),
                    ("name", "name"),
                    ("team_name", "team name"),
                    ("status", "status 2"),
                    ("job_name", "turtle job name"),
                    ("pipeline_name", "turtle pipeline name")
                ])

                validBuildJSONThree = JSON(dictionaryLiteral: [
                    ("id", 3),
                    ("name", "name"),
                    ("team_name", "team name"),
                    ("status", "status 3"),
                    ("job_name", "puppy job name"),
                    ("pipeline_name", "puppy pipeline name")
                ])
            }

            describe("Deserializing builds data where all individual builds are valid") {
                let expectedBuildOne = Build(id: 1, name: "name", teamName:"team name", jobName: "crab job name", status: .started, pipelineName: "crab pipeline name", startTime: 5, endTime: 10)
                let expectedBuildTwo = Build(id: 2, name: "name", teamName:"team name", jobName: "turtle job name", status: .succeeded, pipelineName: "turtle pipeline name", startTime: 5, endTime: 10)
                let expectedBuildThree = Build(id: 2, name: "name", teamName: "team name", jobName: "puppy job name", status: .failed, pipelineName: "puppy pipeline name", startTime: 5, endTime: 10)

                beforeEach {
                    let validBuildsJSON = JSON([
                        validBuildJSONOne,
                        validBuildJSONTwo,
                        validBuildJSONThree
                    ])

                    mockBuildDataDeserializer.when(validBuildJSONOne, thenReturn: expectedBuildOne)
                    mockBuildDataDeserializer.when(validBuildJSONTwo, thenReturn: expectedBuildTwo)
                    mockBuildDataDeserializer.when(validBuildJSONThree, thenReturn: expectedBuildThree)

                    let validData = try! validBuildsJSON.rawData(options: .prettyPrinted)
                    result = StreamResult(subject.deserialize(validData))
                }

                it("emits a build for each JSON build entry") {
                    if result.elements.count != 3 {
                        fail("Expected to return 3 builds, returned \(builds.count)")
                        return
                    }

                    expect(result.elements[0]).to(equal(expectedBuildOne))
                    expect(result.elements[1]).to(equal(expectedBuildTwo))
                    expect(result.elements[2]).to(equal(expectedBuildThree))
                }

                it("emits no error") {
                    expect(result.error).to(beNil())
                }
            }

            describe("Deserializing builds data where one of the builds errors") {
                let expectedBuildOne = Build(id: 1, name: "name", teamName:"team name", jobName: "crab job name", status: .started, pipelineName: "crab pipeline name", startTime: 5, endTime: 10)
                let expectedBuildTwo = Build(id: 3, name: "name", teamName: "team name", jobName: "puppy job name", status: .failed, pipelineName: "puppy pipeline name", startTime: 5, endTime: 10)

                beforeEach {
                    let validBuildsJSON = JSON([
                        validBuildJSONOne,
                        validBuildJSONTwo,
                        validBuildJSONThree
                    ])

                    mockBuildDataDeserializer.when(validBuildJSONOne, thenReturn: expectedBuildOne)
                    mockBuildDataDeserializer.when(validBuildJSONTwo, thenErrorWith: DeserializationError(details: "error", type: .missingRequiredData))
                    mockBuildDataDeserializer.when(validBuildJSONThree, thenReturn: expectedBuildTwo)

                    let validData = try! validBuildsJSON.rawData(options: .prettyPrinted)
                    result = StreamResult(subject.deserialize(validData))
                }

                it("emits a build for each valid JSON build entry") {
                    if result.elements.count != 2 {
                        fail("Expected to return 2 builds, returned \(builds.count)")
                        return
                    }

                    expect(result.elements[0]).to(equal(expectedBuildOne))
                    expect(result.elements[1]).to(equal(expectedBuildTwo))
                }

                it("emits no error") {
                    expect(result.error).to(beNil())
                }
            }

            describe("Given data cannot be interpreted as JSON") {
                var result: (builds: [Build]?, error: DeserializationError?)

                beforeEach {
                    let buildsDataString = "some string"

                    let invalidbuildsData = buildsDataString.data(using: String.Encoding.utf8)
                    result = StreamResult(subject.deserialize(invalidbuildsData!))
                }

                it("emits no builds") {
                    expect(result.elements.count).to(equal(0))
                }

                it("emits an error") {
                    expect(result.error).to(equal(DeserializationError(details: "Could not interpret data as JSON dictionary", type: .invalidInputFormat)))
                }
            }
        }
    }
}
