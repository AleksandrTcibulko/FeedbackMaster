//
//  AppDelegate.swift
//  FeedbackMaster
//
//  Created by Александр Цибулько on 15.03.2026.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?

	func application(
		_ application: UIApplication,
		didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
	) -> Bool {

		let viewController = MainViewController()
		let navigationController = UINavigationController()

		window = UIWindow(frame: UIScreen.main.bounds)
		window?.rootViewController = navigationController
		window?.makeKeyAndVisible()

		navigationController.pushViewController(viewController, animated: true)

		return true
	}
}
