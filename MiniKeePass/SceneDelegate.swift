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

            _databaseDocument = databaseDocument

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

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        _databaseDocument = nil
    }

    @objc func closeDatabase() {
        window?.rootViewController?.dismiss(animated: true, completion: nil)
        _databaseDocument = nil
    }
}
