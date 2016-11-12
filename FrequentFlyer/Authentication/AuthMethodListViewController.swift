import UIKit

class AuthMethodListViewController: UIViewController {
    @IBOutlet weak var authMethodListTableView: UITableView?

    var authMethods: [AuthMethod]? {
        didSet {
            authMethodListTableView?.reloadData()
        }
    }
    var concourseURLString: String?

    class var storyboardIdentifier: String { get { return "AuthMethodList" } }
    class var showBasicUserAuthSegueId: String { get { return "ShowBasicUserAuth" } }
    class var showGithubAuthSegueId: String { get { return "ShowGithubAuth" } }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = ""
        authMethodListTableView?.delegate = self
        authMethodListTableView?.dataSource = self
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == AuthMethodListViewController.showBasicUserAuthSegueId {
            guard let basicUserAuthViewController = segue.destination as? BasicUserAuthViewController else {
                return
            }

            guard let concourseURLString = concourseURLString else { return }
            basicUserAuthViewController.concourseURLString = concourseURLString
            basicUserAuthViewController.keychainWrapper = KeychainWrapper()

            let basicAuthTokenService = BasicAuthTokenService()
            basicAuthTokenService.httpClient = HTTPClient()
            basicAuthTokenService.tokenDataDeserializer = TokenDataDeserializer()
            basicUserAuthViewController.basicAuthTokenService = basicAuthTokenService
        } else if segue.identifier == AuthMethodListViewController.showGithubAuthSegueId {
            guard let githubAuthViewController = segue.destination as? GithubAuthViewController else {
                return
            }

            guard let githubAuthURLString = sender as? String else { return }
            githubAuthViewController.githubAuthURLString = githubAuthURLString

            guard let concourseURLString = concourseURLString else { return }
            githubAuthViewController.concourseURLString = concourseURLString

            githubAuthViewController.keychainWrapper = KeychainWrapper()
            githubAuthViewController.browserAgent = BrowserAgent()

            let tokenValidationService = TokenValidationService()
            tokenValidationService.httpClient = HTTPClient()
            githubAuthViewController.tokenValidationService = tokenValidationService

            githubAuthViewController.userTextInputPageOperator = UserTextInputPageOperator()
        }
    }
}

extension AuthMethodListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let authMethods = authMethods else { return 0 }
        return authMethods.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        if let authMethods = authMethods {
            switch authMethods[indexPath.row].type {
            case .basic:
                cell.textLabel?.text = "Basic"
            case .github:
                cell.textLabel?.text = "Github"
            }
        }

        return cell
    }
}

extension AuthMethodListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let authMethods = authMethods else { return }

        let authMethod = authMethods[indexPath.row]

        switch authMethod.type {
        case .basic:
            performSegue(withIdentifier: AuthMethodListViewController.showBasicUserAuthSegueId, sender: nil)
        case .github:
            performSegue(withIdentifier: AuthMethodListViewController.showGithubAuthSegueId, sender: authMethod.url)
        }
    }
}
