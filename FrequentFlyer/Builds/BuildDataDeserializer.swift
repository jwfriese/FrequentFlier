import Foundation

class BuildDataDeserializer {
    func deserialize(_ data: Data) -> (build: Build?, error: DeserializationError?) {
        var buildJSONObject: Any?
        do {
            buildJSONObject = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
        } catch { }

        guard let buildJSON = buildJSONObject as? NSDictionary else {
            return (nil, DeserializationError(details: "Could not interpret data as JSON dictionary", type: .invalidInputFormat))
        }

        guard let idObject = buildJSON.value(forKey: "id") else {
            return missingDataErrorCaseForKey("id")
        }

        guard let id = idObject as? Int else {
            return typeMismatchErrorCaseForKey("id", expectedType: "an integer")
        }

        guard let jobNameObject = buildJSON.value(forKey: "job_name") else {
            return missingDataErrorCaseForKey("job_name")
        }

        guard let jobName = jobNameObject as? String else {
            return typeMismatchErrorCaseForKey("job_name", expectedType: "a string")
        }

        guard let statusObject = buildJSON.value(forKey: "status") else {
            return missingDataErrorCaseForKey("status")
        }

        guard let status = statusObject as? String else {
            return typeMismatchErrorCaseForKey("status", expectedType: "a string")
        }

        guard let pipelineNameObject = buildJSON.value(forKey: "pipeline_name") else {
            return missingDataErrorCaseForKey("pipeline_name")
        }

        guard let pipelineName = pipelineNameObject as? String else {
            return typeMismatchErrorCaseForKey("pipeline_name", expectedType: "a string")
        }

        let build = Build(id: id,
                          jobName: jobName,
                          status: status,
                          pipelineName: pipelineName)

        return (build, nil)
    }

    fileprivate func missingDataErrorCaseForKey(_ key: String) -> (Build?, DeserializationError?) {
        let error = DeserializationError(details: "Missing required '\(key)' field", type: .missingRequiredData)
        return (nil, error)
    }

    fileprivate func typeMismatchErrorCaseForKey(_ key: String, expectedType: String) -> (Build?, DeserializationError?) {
        let error = DeserializationError(details: "Expected value for '\(key)' field to be \(expectedType)", type: .typeMismatch)
        return (nil, error)
    }
}
