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

class PasswordEntryViewController: UITableViewController, UITextFieldDelegate {
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var showImageView: UIImageView!
    @IBOutlet weak var keyFileLabel: UILabel!

    @objc var filename: String!
    
    @objc private(set) var keyFile: URL?

    @objc var password: String! {
        return passwordTextField.text
    }

    @objc var donePressed: ((PasswordEntryViewController) -> Void)?
    @objc var cancelPressed: ((PasswordEntryViewController) -> Void)?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        passwordTextField.becomeFirstResponder()
        keyFileLabel.text = NSLocalizedString("None", comment: "")
    }
    
    // MARK: - UITextFieldDelegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.donePressedAction(nil)
        return false
    }
    
    // MARK: - UITableViewDataSource
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if (section == 1) {
            return String(format:NSLocalizedString("Enter the password and/or select the keyfile for the %@ database.", comment: ""), filename)
        }
        return nil
    }

    // MARK: UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard indexPath.section == 1 else { return }

        let documentPicker = UIDocumentPickerViewController(documentTypes: ["public.item", "public.content"], in: .open)
        documentPicker.delegate = self
        documentPicker.shouldShowFileExtensions = true
        present(documentPicker, animated: true, completion: nil)
    }
    
    // MARK: - Actions
    
    @IBAction func donePressedAction(_ sender: UIBarButtonItem?) {
        donePressed?(self)
    }
    
    @IBAction func cancelPressedAction(_ sender: UIBarButtonItem?) {
        cancelPressed?(self)
    }
    
    @IBAction func showPressed(_ sender: UITapGestureRecognizer) {
        if (!passwordTextField.isSecureTextEntry) {
            // Clear the password first, since you can't edit a secure text entry once set
            passwordTextField.text = ""
            passwordTextField.isSecureTextEntry = true
            
            // Change the image
            showImageView.image = UIImage(named: "eye")
        } else {
            passwordTextField.isSecureTextEntry = false
            
            // Change the image
            showImageView.image = UIImage(named: "eye-slash")
        }
    }
}

extension PasswordEntryViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let documentURL = urls.first else { return }
        keyFile = documentURL
        keyFileLabel.text = documentURL.lastPathComponent
    }
}
