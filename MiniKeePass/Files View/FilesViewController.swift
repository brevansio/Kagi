/*
 * Copyright 2016 Jason Rush and John Flanagan. All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import UIKit

class FilesViewController: UIDocumentBrowserViewController, UIDocumentBrowserViewControllerDelegate {
    var importHandler: ((URL?, UIDocumentBrowserViewController.ImportMode) -> Void)?


    override func viewDidLoad() {
        super.viewDidLoad();

        delegate = self

        allowsDocumentCreation = true
        allowsPickingMultipleItems = false
        view.tintColor = UIColor.init(named: "tintColor")

    }

    // MARK: UIDocumentBrowserViewControllerDelegate

    func documentBrowser(_ controller: UIDocumentBrowserViewController, didRequestDocumentCreationWithHandler importHandler: @escaping (URL?, UIDocumentBrowserViewController.ImportMode) -> Void) {
        let storyboard = UIStoryboard(name: "NewDatabase", bundle: nil)
        guard let navController = storyboard.instantiateInitialViewController() as? UINavigationController,
            let newDatabaseViewController = navController.viewControllers.first as? NewDatabaseViewController else {
                importHandler(nil, .none)
                return
        }

        newDatabaseViewController.delegate = self
        self.importHandler = importHandler
        present(navController, animated: true, completion: nil)
    }

    func documentBrowser(_ controller: UIDocumentBrowserViewController, didPickDocumentsAt documentURLs: [URL]) {
        guard let sourceURL = documentURLs.first else { return }

        // Present the Document View Controller for the first document that was picked.
        // If you support picking multiple items, make sure you handle them all.
        presentDocument(at: sourceURL)
    }

    func documentBrowser(_ controller: UIDocumentBrowserViewController, didImportDocumentAt sourceURL: URL, toDestinationURL destinationURL: URL) {
        // Present the Document View Controller for the new newly created document
        presentDocument(at: destinationURL)
    }

    func documentBrowser(_ controller: UIDocumentBrowserViewController, failedToImportDocumentAt documentURL: URL, error: Error?) {
        // Make sure to handle the failed import appropriately, e.g., by presenting an error message to the user.
    }

    // MARK: Document Presentation

    func presentDocument(at documentURL: URL) {
        let databaseManager = DatabaseManager.sharedInstance()
        databaseManager?.openDatabaseDocument(documentURL, in: view.window, animated: true)
    }
}

// MARK: NewDatabaseDelegate

extension FilesViewController: NewDatabaseDelegate {
    func shouldUseTemporaryLocation() -> Bool {
        importHandler != nil
    }

    func newDatabaseCreated(url: URL?) {
        guard let successfulURL = url else {
            importHandler?(nil, .none)
            return
        }

        importHandler?(successfulURL, .move)
    }
}
