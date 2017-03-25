import UIKit

class GithubAuthViewController: UIViewController {
    @IBOutlet weak var scrollView: UIScrollView?
    @IBOutlet weak var openGithubAuthPageButton: RoundedButton?
    @IBOutlet weak var tokenTextField: UnderlineTextField?
    @IBOutlet weak var stayLoggedInSwitch: UISwitch?
    @IBOutlet weak var loginButton: RoundedButton?

    var keychainWrapper = KeychainWrapper()
    var httpSessionUtils = HTTPSessionUtils()
    var tokenValidationService = TokenValidationService()
    var userTextInputPageOperator = UserTextInputPageOperator()

    var concourseURLString: String?
    var githubAuthURLString: String?

    class var storyboardIdentifier: String { get { return "GithubAuth" } }
    class var setTeamPipelinesAsRootPageSegueId: String { get { return "SetTeamPipelinesAsRootPage" } }
    class var showGithubAuthenticationWebPageSegueId: String { get { return "ShowGithubAuthenticationWebPage" } }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = ""

        openGithubAuthPageButton?.setUp(withTitleText: "Get Token",
                                        titleFont: Style.Fonts.button,
                                        controlStateTitleColors: [.normal : #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)],
                                        controlStateButtonColors: [.normal : Style.Colors.buttonNormal]
        )

        loginButton?.setUp(withTitleText: "Log In",
                           titleFont: Style.Fonts.button,
                           controlStateTitleColors: [.normal : #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)],
                           controlStateButtonColors: [.normal : Style.Colors.buttonNormal]
        )

        tokenTextField?.textField?.delegate = self
        tokenTextField?.textField?.placeholder = "Paste token here"
        loginButton?.isEnabled = false
        userTextInputPageOperator.delegate = self
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == GithubAuthViewController.setTeamPipelinesAsRootPageSegueId {
            guard let target = sender as? Target else { return }
            guard let teamPipelinesViewController = segue.destination as? TeamPipelinesViewController else {
                return
            }

            teamPipelinesViewController.target = target

            let teamPipelinesService = TeamPipelinesService()
            teamPipelinesService.httpClient = HTTPClient()
            teamPipelinesService.pipelineDataDeserializer = PipelineDataDeserializer()
            teamPipelinesViewController.teamPipelinesService = teamPipelinesService

            teamPipelinesViewController.keychainWrapper = KeychainWrapper()
        } else if segue.identifier == GithubAuthViewController.showGithubAuthenticationWebPageSegueId {
            guard let githubAuthURLString = githubAuthURLString else { return }

            guard let webViewController = segue.destination as? WebViewController else {
                return
            }

            webViewController.webPageURL = URL(string: githubAuthURLString)
        }
    }

    @IBAction func openGithubAuthPageButtonTapped() {
        DispatchQueue.main.async {
            self.performSegue(withIdentifier: GithubAuthViewController.showGithubAuthenticationWebPageSegueId, sender: nil)
        }
    }

    @IBAction func logInButtonTapped() {
        guard let concourseURLString = concourseURLString else { return }
        guard let tokenString = tokenTextField?.textField?.text else { return }

        loginButton?.isEnabled = false

        httpSessionUtils.deleteCookies()

        tokenValidationService.validate(token: Token(value: tokenString), forConcourse: concourseURLString) { error in
            if let error = error {
                let alert = UIAlertController(title: "Authorization Failed",
                                              message: error.details,
                                              preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))

                DispatchQueue.main.async {
                    self.loginButton?.isEnabled = true
                    self.present(alert, animated: true, completion: nil)
                }
            } else {
                let token = Token(value: tokenString)
                let newTarget = Target(name: "target",
                                       api: concourseURLString,
                                       teamName: "main",
                                       token: token)
                if self.stayLoggedInSwitch != nil && self.stayLoggedInSwitch!.isOn {
                    self.keychainWrapper.saveTarget(newTarget)
                }

                DispatchQueue.main.async {
                    self.performSegue(withIdentifier: GithubAuthViewController.setTeamPipelinesAsRootPageSegueId, sender: newTarget)
                }
            }
        }
    }
}

extension GithubAuthViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let willHaveText = string != ""
        loginButton?.isEnabled = willHaveText
        return true
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        loginButton?.isEnabled = false
        return true
    }
}

extension GithubAuthViewController: UserTextInputPageDelegate {
    var textFields: [UITextField] { get { return [tokenTextField!.textField!] } }
    var pageView: UIView { get { return view } }
    var pageScrollView: UIScrollView { get { return scrollView! } }
}
