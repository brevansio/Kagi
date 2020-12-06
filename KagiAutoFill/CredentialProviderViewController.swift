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

    @objc func deleteAllData() {
        AppSettings.sharedInstance()?.setPinFailedAttempts(0)
        AppSettings.sharedInstance()?.setPinEnabled(false)
        AppSettings.sharedInstance()?.setBiometricsEnabled(false)

        KeychainUtils.deleteString(forKey: "PIN", andServiceName: KEYCHAIN_PIN_SERVICE)
        KeychainUtils.deleteAll(forServiceName: KEYCHAIN_PASSWORDS_SERVICE)
        KeychainUtils.deleteAll(forServiceName: KEYCHAIN_KEYFILES_SERVICE)
        closeDatabase()
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

    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
    }

    override func provideCredentialWithoutUserInteraction(for credentialIdentity: ASPasswordCredentialIdentity) {
        self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain,
                                                               code: ASExtensionError.userInteractionRequired.rawValue))
    }

    override func prepareInterfaceToProvideCredential(for credentialIdentity: ASPasswordCredentialIdentity) {
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
