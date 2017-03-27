import Foundation
import RxSwift

extension ObservableType {
    func replayAllAndConnect() -> Observable<Self.E> {
        let replayObservable = self.replayAll()
        _ = replayObservable.connect()
        return replayObservable
    }
}

class AuthMethodsService {
    var httpClient = HTTPClient()
    var authMethodsDataDeserializer = AuthMethodDataDeserializer()

    func getMethods(forTeamName teamName: String, concourseURL: String) -> Observable<AuthMethod> {
        let urlString = "\(concourseURL)/api/v1/teams/\(teamName)/auth/methods"
        let url = URL(string: urlString)
        var request = URLRequest(url: url!)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "GET"

        let http$ = httpClient.perform(request: request)
        return http$
            .asObservable()
            .flatMap { response in
                self.authMethodsDataDeserializer.deserialize(response.body!)
        }
    }
}
