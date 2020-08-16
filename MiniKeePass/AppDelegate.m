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

#import "AppDelegate.h"
#import "EntryViewController.h"
#import "AppSettings.h"
#import "DatabaseManager.h"
#import "KeychainUtils.h"
#import "LockScreenManager.h"
#import "Kagi-Swift.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    // Add a pasteboard notification listener to support clearing the clipboard
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self
                           selector:@selector(handlePasteboardNotification:)
                               name:UIPasteboardChangedNotification
                             object:nil];

    [self checkFileProtection];
    [[IAPManager shared] requestProducts];

    // This is for the UIDocumentPickerVCs, but they use UIDocumentBrowserVC under the hood
    [[UINavigationBar appearanceWhenContainedInInstancesOfClasses:@[[UIDocumentBrowserViewController class]]] setTintColor:[UIColor colorNamed:@"tintColor"]];

    return YES;
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Check file protection
    [self checkFileProtection];
}

+ (NSString *)documentsDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [paths objectAtIndex:0];
}

+ (NSURL *)cacheDirectoryUrl {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *urls = [fileManager URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask];
    return [urls firstObject];
}

+ (void)deleteKeychainData {
    // Reset some settings
    AppSettings *appSettings = [AppSettings sharedInstance];
    [appSettings setPinFailedAttempts:0];
    [appSettings setPinEnabled:NO];
    [appSettings setBiometricsEnabled:NO];

    // Delete the PIN from the keychain
    [KeychainUtils deleteStringForKey:@"PIN" andServiceName:KEYCHAIN_PIN_SERVICE];

    // Delete all database passwords from the keychain
    [KeychainUtils deleteAllForServiceName:KEYCHAIN_PASSWORDS_SERVICE];
    [KeychainUtils deleteAllForServiceName:KEYCHAIN_KEYFILES_SERVICE];
}

+ (void)deleteAllData {
    // Close the current database
    NSSet<UIScene *> *scenes = [[UIApplication sharedApplication] connectedScenes];
    for (UIScene *scene in scenes) {
        NSURL *url = [(SceneDelegate *)scene.delegate databaseDocument].url;
        [(SceneDelegate *)scene.delegate closeDatabase];
        [[NSFileManager defaultManager] removeItemAtURL:url error:nil];

    }

    // Delete data stored in system keychain
    [self deleteKeychainData];
}

- (void)checkFileProtection {
    // Get the document's directory
    NSString *documentsDirectory = [AppDelegate documentsDirectory];

    // Get the contents of the documents directory
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *dirContents = [fileManager contentsOfDirectoryAtPath:documentsDirectory error:nil];

    // Check all files to see if protection is enabled
    for (NSString *file in dirContents) {
        if (![file hasPrefix:@"."]) {
            NSString *path = [documentsDirectory stringByAppendingPathComponent:file];

            BOOL dir = NO;
            [fileManager fileExistsAtPath:path isDirectory:&dir];
            if (!dir) {
                // Make sure file protecten is turned on
                NSDictionary *attributes = [fileManager attributesOfItemAtPath:path error:nil];
                NSString *fileProtection = [attributes valueForKey:NSFileProtectionKey];
                if (![fileProtection isEqualToString:NSFileProtectionComplete]) {
                    [fileManager setAttributes:@{NSFileProtectionKey:NSFileProtectionComplete} ofItemAtPath:path error:nil];
                }
            }
        }
    }
}

- (void)handlePasteboardNotification:(NSNotification *)notification {
    // Catalyst has a bug when accessing the generalPasteboard here. Probably due to it being accessed in app in
    // quick succession. Adding the extra async fixes this issue.
#if TARGET_OS_MACCATALYST
    dispatch_async(dispatch_get_main_queue(), ^{
#endif
        // Check if the clipboard has any contents
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        if (pasteboard.string == nil || [pasteboard.string isEqualToString:@""]) {
            return;
        }
        
        AppSettings *appSettings = [AppSettings sharedInstance];
        
        // Check if the clearing the clipboard is enabled
        if ([appSettings clearClipboardEnabled]) {
            // Get the "version" of the pasteboard contents
            NSInteger pasteboardVersion = pasteboard.changeCount;
            
            // Get the clear clipboard timeout (in seconds)
            NSInteger clearClipboardTimeout = [appSettings clearClipboardTimeout];
            
            UIApplication *application = [UIApplication sharedApplication];
            
            // Initiate a background task
            __block UIBackgroundTaskIdentifier bgTask;
            bgTask = [application beginBackgroundTaskWithExpirationHandler:^{
                // End the background task
                [application endBackgroundTask:bgTask];
            }];
            
            // Start the long-running task and return immediately.
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                // Sleep until it's time to clean the clipboard
                [NSThread sleepForTimeInterval:clearClipboardTimeout];
                
                // Clear the clipboard if it hasn't changed
                if (pasteboardVersion == pasteboard.changeCount) {
                    pasteboard.string = @"";
                }

                // End the background task
                [application endBackgroundTask:bgTask];
            });
        }
#if TARGET_OS_MACCATALYST
    });
#endif
}

- (void)buildMenuWithBuilder:(id<UIMenuBuilder>)builder {
    if ([builder system] != [UIMenuSystem mainSystem]) {
        return;
    }

    [builder removeMenuForIdentifier:UIMenuFormat];
    [builder removeMenuForIdentifier:UIMenuView];
    [builder removeMenuForIdentifier:UIMenuClose];
    [builder removeMenuForIdentifier:UIMenuNewScene];
    [builder removeMenuForIdentifier:UIMenuSpelling];
    [builder removeMenuForIdentifier:UIMenuSubstitutions];

    UIKeyCommand *newCommand = [UIKeyCommand commandWithTitle:NSLocalizedString(@"New Database", nil)
                                                        image:nil
                                                       action:@selector(newDatabase:)
                                                        input:@"n"
                                                modifierFlags:UIKeyModifierCommand
                                                 propertyList:nil];
    UIKeyCommand *openCommand = [UIKeyCommand commandWithTitle:NSLocalizedString(@"Open Database", nil)
                                                        image:nil
                                                       action:@selector(openDatabase:)
                                                        input:@"o"
                                                modifierFlags:UIKeyModifierCommand
                                                 propertyList:nil];

    UIKeyCommand *newEntryCommand = [UIKeyCommand commandWithTitle:NSLocalizedString(@"New Entry", nil)
                                                             image:nil
                                                            action:@selector(addNewEntry)
                                                             input:@"e"
                                                     modifierFlags:UIKeyModifierCommand
                                                      propertyList:nil];

    UIKeyCommand *newGroupCommand = [UIKeyCommand commandWithTitle:NSLocalizedString(@"New Group", nil)
                                                             image:nil
                                                            action:@selector(addNewGroup)
                                                             input:@"g"
                                                     modifierFlags:UIKeyModifierCommand
                                                      propertyList:nil];
    UIKeyCommand *closeDBCommand = [UIKeyCommand commandWithTitle:NSLocalizedString(@"Close", nil)
                                                            image:nil
                                                           action:@selector(closeDB:)
                                                            input:@"w"
                                                    modifierFlags:UIKeyModifierCommand
                                                     propertyList:nil];

    UIMenu *newFileMenu = [UIMenu menuWithTitle:@""
                                          image:nil
                                     identifier:@""
                                        options:UIMenuOptionsDisplayInline
                                       children:@[newCommand, openCommand, newEntryCommand, newGroupCommand, closeDBCommand]];
    [builder insertChildMenu:newFileMenu atEndOfMenuForIdentifier:UIMenuFile];
}

- (IBAction)newDatabase:(id)sender {
    NSUserActivity *activity = [[NSUserActivity alloc] initWithActivityType:@"newDatabase"];
    [[UIApplication sharedApplication] requestSceneSessionActivation:nil
                                                        userActivity:activity
                                                             options:nil
                                                        errorHandler:nil];
}

- (IBAction)openDatabase:(id)sender {
    [[UIApplication sharedApplication] requestSceneSessionActivation:nil
                                                        userActivity:nil
                                                             options:nil
                                                        errorHandler:nil];
}

@end
