//
//  CredentialProviderViewController.swift
//  KagiAutoFill
//
//  Created by Bruce Evans on 2020/09/15.
//  Copyright © 2020 Self. All rights reserved.
//

import AuthenticationServices

class CredentialProviderViewController: ASCredentialProviderViewController {
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

            let storyboard = UIStoryboard(name: "MainInterface", bundle: nil)
            guard let navController = storyboard.instantiateViewController(identifier: "OpenDatabase") as? UINavigationController,
                let groupViewController = navController.viewControllers.first as? GroupViewController else {
                    closeDatabase()
                    return
            }

            groupViewController.parentGroup = newDocument.kdbTree.root
            groupViewController.title = URL(fileURLWithPath: newDocument.filename).lastPathComponent

            navController.willMove(toParent: self)
            navController.view.frame = view.bounds
            view.addSubview(navController.view)
            addChild(navController)
            navController.didMove(toParent: self)
        }
    }

    @objc func closeDatabase() {
        children.forEach { $0.removeFromParent() }
        _databaseDocument = nil
        self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain,
                                                               code: ASExtensionError.userCanceled.rawValue))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        lockScreenManager = LockScreenManager(viewController: self)
        lockScreenManager?.delegate = self;

        if lockScreenManager?.shouldCloseDatabase() != false {
            dismiss(animated: true, completion: nil)
            _databaseDocument = nil
        }

        if lockScreenManager?.shouldCheckPin() == true {
            lockScreenManager?.showLockScreen()
            lockScreenManager?.checkPin()
        } else {
            lockScreenManager?.hideLockScreen()
        }
    }

    func userChose(username: String, password: String) {
        closeDatabase()
        let credential = ASPasswordCredential(user: username, password: password)
        self.extensionContext.completeRequest(withSelectedCredential: credential, completionHandler: nil)
    }

    /*
     Prepare your UI to list available credentials for the user to choose from. The items in
     'serviceIdentifiers' describe the service the user is logging in to, so your extension can
     prioritize the most relevant credentials in the list.
    */
    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
    }

    /*
     Implement this method if your extension supports showing credentials in the QuickType bar.
     When the user selects a credential from your app, this method will be called with the
     ASPasswordCredentialIdentity your app has previously saved to the ASCredentialIdentityStore.
     Provide the password by completing the extension request with the associated ASPasswordCredential.
     If using the credential would require showing custom UI for authenticating the user, cancel
     the request with error code ASExtensionError.userInteractionRequired.
    */
    override func provideCredentialWithoutUserInteraction(for credentialIdentity: ASPasswordCredentialIdentity) {
        self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain,
                                                               code: ASExtensionError.userInteractionRequired.rawValue))
    }

    /*
     Implement this method if provideCredentialWithoutUserInteraction(for:) can fail with
     ASExtensionError.userInteractionRequired. In this case, the system may present your extension's
     UI and call this method. Show appropriate UI for authenticating the user then provide the password
     by completing the extension request with the associated ASPasswordCredential.
    */
    override func prepareInterfaceToProvideCredential(for credentialIdentity: ASPasswordCredentialIdentity) {
        // TODO: Show PIN if needed
        // Show File Picker
        let documentPicker = UIDocumentPickerViewController(documentTypes: ["public.item", "public.content"], in: .open)
        documentPicker.delegate = self
        documentPicker.shouldShowFileExtensions = true
        present(documentPicker, animated: true, completion: nil)
    }
}

extension CredentialProviderViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let documentURL = urls.first else { return }
        let databaseManager = DatabaseManager.sharedInstance()
        databaseManager?.openDatabaseDocument(documentURL, in: view.window, animated: true)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain,
                                                               code: ASExtensionError.userCanceled.rawValue))
    }
}

extension CredentialProviderViewController: LockScreenDelegate {
    @objc func lockScreenWasHidden() {
        let documentPicker = UIDocumentPickerViewController(documentTypes: ["public.item", "public.content"], in: .open)
        documentPicker.delegate = self
        documentPicker.shouldShowFileExtensions = true
        present(documentPicker, animated: true, completion: nil)
    }
}
