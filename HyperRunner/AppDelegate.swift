import UIKit
import HyperTalkIOS

enum HyperRunnerError: Error {
    case fileNotFound(name: String)
    case scriptParserFailed
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var script: Script!
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    
        do {
            guard let appScriptURL = Bundle.main.url(forResource: "main", withExtension: "hc") else { throw HyperRunnerError.fileNotFound(name: "main.hc") }
            script = try Script(contentsOf: appScriptURL)
            
            var context = RunContext(script: script)
            try context.run("startup", isCommand: true)
        } catch {
            print("error: \(error)")
        }
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}

