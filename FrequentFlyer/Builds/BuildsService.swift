import Foundation

class BuildsService {
    var httpClient: HTTPClient?
    var buildsDataDeserializer: BuildsDataDeserializer?

    func getBuilds(forTarget target: Target, completion: (([Build]?, FFError?) -> ())?) {
        guard let httpClient = httpClient else { return }

        let urlString = "\(target.api)/api/v1/builds"
        guard let url = URL(string: urlString) else { return }

        let request = NSMutableURLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(target.token.value)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "GET"

        httpClient.doRequest(request as URLRequest) { data, response, error in
            guard let completion = completion else { return }
            guard let data = data else {
                completion(nil, error)
                return
            }

            let result = self.buildsDataDeserializer?.deserialize(data)
            completion(result?.builds, result?.error)
        }
    }
}
