/*
 * Copyright 2011-2012 Jason Rush and John Flanagan. All rights reserved.
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

#import "DatabaseManager.h"
#import "AppDelegate.h"
#import "KeychainUtils.h"
#import "AppSettings.h"
#import "MiniKeePass-Swift.h"

@implementation DatabaseManager

static DatabaseManager *sharedInstance;

+ (void)initialize {
    static BOOL initialized = NO;
    if (!initialized)     {
        initialized = YES;
        sharedInstance = [[DatabaseManager alloc] init];
    }
}

+ (DatabaseManager*)sharedInstance {
    return sharedInstance;
}

- (void)newDatabase:(NSURL *)url password:(NSString *)password version:(NSInteger)version {
    // Create the KdbWriter for the requested version
    id<KdbWriter> writer;
    if (version == 1) {
        writer = [[Kdb3Writer alloc] init];
    } else {
        writer = [[Kdb4Writer alloc] init];
    }
    
    // Create the KdbPassword
    KdbPassword *kdbPassword = [[KdbPassword alloc] initWithPassword:password
                                                    passwordEncoding:NSUTF8StringEncoding
                                                             keyFile:nil];
    
    // Create the new database
    [writer newFile:url.path withPassword:kdbPassword];
    
    // Store the password in the keychain
    if ([[AppSettings sharedInstance] rememberPasswordsEnabled]) {
        NSString *filename = url.lastPathComponent;
        [KeychainUtils setString:password forKey:filename andServiceName:KEYCHAIN_PASSWORDS_SERVICE];
    }
}

- (void)openDatabaseDocument:(NSURL *)documentURL animated:(BOOL)animated {
    BOOL databaseLoaded = NO;
    self.selectedURL = documentURL;

    // Get the application delegate
    AppDelegate *appDelegate = [AppDelegate getDelegate];
    
    // Load the password and keyfile from the keychain
    NSString *password = [KeychainUtils stringForKey:self.selectedURL.lastPathComponent
                                      andServiceName:KEYCHAIN_PASSWORDS_SERVICE];

    // Try and load the database with the cached password from the keychain
    if (password != nil) {
        // Load the database
        @try {
            DatabaseDocument *dd = [[DatabaseDocument alloc] initWithURL:documentURL password:password keyFile:nil];

            databaseLoaded = YES;

            // Set the database document in the application delegate
            appDelegate.databaseDocument = dd;
        } @catch (NSException *exception) {
            // Ignore
        }
    }

    // Prompt the user for the password if we haven't loaded the database yet
    if (!databaseLoaded) {
        // Prompt the user for a password
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"PasswordEntry" bundle:nil];
        UINavigationController *navigationController = [storyboard instantiateInitialViewController];

        PasswordEntryViewController *passwordEntryViewController = (PasswordEntryViewController *)navigationController.topViewController;
        passwordEntryViewController.donePressed = ^(PasswordEntryViewController *passwordEntryViewController) {
            [self openDatabaseWithPasswordEntryViewController:passwordEntryViewController];
        };
        passwordEntryViewController.cancelPressed = ^(PasswordEntryViewController *passwordEntryViewController) {
            [passwordEntryViewController dismissViewControllerAnimated:YES completion:nil];
        };

        // Initialize the filename
        passwordEntryViewController.filename = documentURL.lastPathComponent;

        [appDelegate.window.rootViewController presentViewController:navigationController animated:animated completion:nil];
    }
}

- (void)openDatabaseWithPasswordEntryViewController:(PasswordEntryViewController *)passwordEntryViewController {
    // Get the password
    NSString *password = passwordEntryViewController.password;
    if ([password isEqualToString:@""]) {
        password = nil;
    }

    // Get the keyfile
    NSString *keyFilePath = passwordEntryViewController.keyFile.absoluteString;

    // Load the database
    @try {
        // Open the database
        DatabaseDocument *dd = [[DatabaseDocument alloc] initWithURL:self.selectedURL password:password keyFile:passwordEntryViewController.keyFile];

        // Store the password in the keychain
        if ([[AppSettings sharedInstance] rememberPasswordsEnabled]) {
            [KeychainUtils setString:password forKey:self.selectedURL.lastPathComponent
                      andServiceName:KEYCHAIN_PASSWORDS_SERVICE];
            [KeychainUtils setString:keyFilePath forKey:self.selectedURL.lastPathComponent
                      andServiceName:KEYCHAIN_KEYFILES_SERVICE];
        }

        // Dismiss the view controller, and after animation set the database document
        [passwordEntryViewController dismissViewControllerAnimated:YES completion:^{
            // Set the database document in the application delegate
            AppDelegate *appDelegate = [AppDelegate getDelegate];
            appDelegate.databaseDocument = dd;
        }];
    } @catch (NSException *exception) {
        NSLog(@"%@", exception);
        
        NSString *title = NSLocalizedString(@"Error", comment: "");
        NSString *message = NSLocalizedString(@"Could not open database", comment: "");
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [passwordEntryViewController presentViewController:alertController animated:YES completion:nil];
    }
}

@end
