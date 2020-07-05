//
//  SceneDelegate.swift
//  Kagi
//
//  Created by Bruce Evans on 2020/06/26.
//  Copyright © 2020 Self. All rights reserved.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow? {
        didSet {
            guard let window = window else { return }
            lockScreenManager = LockScreenManager(window: window)
        }
    }

    private var lockScreenManager: LockScreenManager?


    private var _databaseDocument: DatabaseDocument?
    @objc var databaseDocument: DatabaseDocument? {
        get {
            return _databaseDocument
        }
        set {
            if _databaseDocument != nil {
                closeDatabase()
            }

            guard let newDocument = newValue else { return }

            _databaseDocument = newDocument

            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            guard let navController = storyboard.instantiateViewController(identifier: "OpenDatabase") as? UINavigationController,
                let groupViewController = navController.viewControllers.first as? GroupViewController else {
                    closeDatabase()
                    return
            }

            groupViewController.parentGroup = newDocument.kdbTree.root
            groupViewController.title = URL(fileURLWithPath: newDocument.filename).lastPathComponent

            window?.rootViewController?.present(navController, animated: true, completion: nil)
        }
    }

    var onActivationAction: (()->())?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        _databaseDocument = nil

        if !connectionOptions.userActivities.filter({ $0.activityType == "newDatabase" }).isEmpty {
            onActivationAction = {
                let storyboard = UIStoryboard(name: "NewDatabase", bundle: nil)
                guard let navController = storyboard.instantiateInitialViewController() as? UINavigationController,
                    let newDatabaseViewController = navController.viewControllers.first as? NewDatabaseViewController,
                    let filesController = self.window?.rootViewController as? FilesViewController else {
                        return
                }

                newDatabaseViewController.delegate = filesController
                filesController.present(navController, animated: true, completion: nil)
            }
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        onActivationAction?()
    }

    @objc func closeDatabase() {
        window?.rootViewController?.dismiss(animated: true, completion: nil)
        _databaseDocument = nil
    }
}
