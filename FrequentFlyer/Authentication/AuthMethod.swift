struct AuthMethod {
    fileprivate(set) var type: AuthType
    fileprivate(set) var url: String

    init(type: AuthType, url: String) {
        self.type = type
        self.url = url
    }
}

extension AuthMethod: Equatable {}

func ==(lhs: AuthMethod, rhs: AuthMethod) -> Bool {
    return lhs.type == rhs.type && lhs.url == rhs.url
}
