/*
 * Copyright 2011-2014 Jason Rush and John Flanagan. All rights reserved.
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

// See Technical Q&A QA1838

#import <LocalAuthentication/LocalAuthentication.h>
#import <AudioToolbox/AudioToolbox.h>
#import "LockScreenManager.h"
#import "AppSettings.h"
#import "KeychainUtils.h"
#import "PinViewController.h"
#import "PasswordUtils.h"

#ifdef TARGET_KAGIAPP
#import "AppDelegate.h"
#import "Kagi-Swift.h"
#endif

@interface LockScreenManager () <PinViewControllerDelegate>
@property (nonatomic, strong) PinViewController *pinViewController;
@end

@implementation LockScreenManager {
    UIWindow *lockWindow;
    BOOL biometricsAuthFailed;
}

- (instancetype)initWithWindow:(UIWindow *)window {
    self = [super init];
    if (self) {
        biometricsAuthFailed = NO;
        
        lockWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        lockWindow.windowLevel = UIWindowLevelAlert;
        lockWindow.windowScene = window.windowScene;
        
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        blurView.frame = [[UIScreen mainScreen] bounds];
        self.pinViewController = [[PinViewController alloc] init];
        self.pinViewController.delegate = self;

        lockWindow.rootViewController = self.pinViewController;
        [lockWindow addSubview:blurView];

        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        [notificationCenter addObserver:self
                               selector:@selector(sceneWillConnect:)
                                   name:UISceneWillConnectNotification
                                 object:window.windowScene];
        [notificationCenter addObserver:self
                               selector:@selector(sceneWillEnterForeground:)
                                   name:UISceneWillEnterForegroundNotification
                                 object:window.windowScene];
        [notificationCenter addObserver:self
                               selector:@selector(sceneDidEnterBackground:)
                                   name:UISceneDidEnterBackgroundNotification
                                 object:window.windowScene];
    }
    return self;
}

- (void)dealloc {
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self];
}

#pragma mark - Lock/Unlock

- (BOOL)shouldCheckPin {
    // Check if the PIN is enabled
    AppSettings *appSettings = [AppSettings sharedInstance];
    if (![appSettings pinEnabled]) {
        return NO;
    }
    
    // Check if biometrics check failed
    if (biometricsAuthFailed) {
        return YES;
    }

    // Get the last time the app exited
    NSDate *exitTime = [appSettings exitTime];
    if (exitTime == nil) {
        return YES;
    }

    // Check if enough time has ellapsed
    NSTimeInterval timeInterval = ABS([exitTime timeIntervalSinceNow]);
    return timeInterval > [appSettings pinLockTimeout];
}

- (void)checkPin {
    // Perform Touch/Face ID if enabled and not already failed.
    AppSettings *appSettings = [AppSettings sharedInstance];
    if ([appSettings biometricsEnabled] && !biometricsAuthFailed) {
        [self showBiometricAuth];
    }
}

- (void)hideLockScreen {

    [UIView animateWithDuration:0.25
                     animations:^{
                        self->lockWindow.alpha = 0.0;
                     }
                     completion:^(BOOL finished){
                         [self.pinViewController clearPin];
                            self->biometricsAuthFailed = NO;
                            self->lockWindow.hidden = YES;
                            self->lockWindow.alpha = 1.0;
                     }];
}

- (void)showBiometricAuth {
    // Check if TouchID/FaceID is supported
    if (![NSClassFromString(@"LAContext") class]) {
        // Fallback to the PIN screen
        return;
    }

    LAContext *context = [[LAContext alloc] init];
    context.localizedFallbackTitle = @""; // Hide the fallback button

    // Check if Touch/Face ID is available
    NSError *error = nil;
    if (![context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error]) {
        // Fallback to the PIN screen
        return;
    }
    
    biometricsAuthFailed = NO;
    
    // Authenticate User
    [context evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
            localizedReason:NSLocalizedString(@"Unlock Kagi", nil)
                      reply:^(BOOL success, NSError *error) {
                          if (success) {
                              // Dismiss the lock screen
                              dispatch_async(dispatch_get_main_queue(), ^{
                                  [self hideLockScreen];
                              });
                          } else {
                              // Failed, show the PIN screen
                              self->biometricsAuthFailed = YES;
                          }
                      }];
}

#pragma mark - PinViewController delegate methods

- (void)pinViewController:(PinViewController *)pinViewController pinEntered:(NSString *)pin {
    AppSettings *appSettings = [AppSettings sharedInstance];
    NSString *validPin = [appSettings pin];
    
    if (validPin == nil) {
        [pinViewController clearPin];
        pinViewController.titleLabel.text = NSLocalizedString(@"Error Checking PIN", nil);
    } else {
        // Check if the PIN is valid
        if ([PasswordUtils validatePassword:pin againstHash:validPin]) {
            // Reset the number of pin failed attempts
            [appSettings setPinFailedAttempts:0];

            // Dismiss the PIN screen
            [self hideLockScreen];
        } else {
            // Vibrate to signify they are a bad user
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
            [pinViewController clearPin];

            if (![appSettings deleteOnFailureEnabled]) {
                // Update the status message on the PIN view
                pinViewController.titleLabel.text = NSLocalizedString(@"Incorrect PIN", nil);
            } else {
                // Get the number of failed attempts
                NSInteger pinFailedAttempts = [appSettings pinFailedAttempts];
                [appSettings setPinFailedAttempts:++pinFailedAttempts];

                // Get the number of failed attempts before deleting
                NSInteger deleteOnFailureAttempts = [appSettings deleteOnFailureAttempts];

                // Update the status message on the PIN view
                NSInteger remainingAttempts = (deleteOnFailureAttempts - pinFailedAttempts);

                // Update the incorrect pin message
                if (remainingAttempts > 0) {
                    pinViewController.titleLabel.text = [NSString stringWithFormat:@"%@: %ld", NSLocalizedString(@"Attempts Remaining", nil), (long)remainingAttempts];
                } else {
                    pinViewController.titleLabel.text = NSLocalizedString(@"Incorrect PIN", nil);
                }

                // Check if they have failed too many times
                if (pinFailedAttempts >= deleteOnFailureAttempts) {
                    // Delete all data
#if TARGET_KAGIAPP
                    [AppDelegate deleteAllData];
#elif TARGET_KAGIAUTOFILL
                    // TODO
#endif

                    // Dismiss the PIN screen
                    [self hideLockScreen];
                }
            }
        }
    }
}

#pragma mark - Closing the database

- (BOOL)shouldCloseDatabase {
    // Check if Close on Timeout is enabled
    AppSettings *appSettings = [AppSettings sharedInstance];
    if (![appSettings closeEnabled]) {
        return NO;
    }
    
    // Get the last time the app exited
    NSDate *exitTime = [appSettings exitTime];
    if (exitTime == nil) {
        return YES;
    }
    
    // Check if enough time has ellapsed
    NSTimeInterval timeInterval = ABS([exitTime timeIntervalSinceNow]);
    return timeInterval > [appSettings closeTimeout];
}

#pragma mark - Application Notification Handlers

- (void)sceneWillConnect:(NSNotification *)notification {
    // Lock if the PIN is enabled
    AppSettings *appSettings = [AppSettings sharedInstance];
    if ([appSettings pinEnabled]) {
        [lockWindow makeKeyAndVisible];
        [self checkPin];
    }
}

- (void)sceneWillEnterForeground:(NSNotification *)notification {
    if ([self shouldCloseDatabase]) {
#ifdef TARGET_KAGIAPP
        SceneDelegate *sceneDelegate = (SceneDelegate *)lockWindow.windowScene.delegate;
        [sceneDelegate closeDatabase];
#endif
    }
    
    if ([self shouldCheckPin]) {
        [self checkPin];
    } else {
        [self hideLockScreen];
    }
}

- (void)sceneDidEnterBackground:(NSNotification *)notification {
    AppSettings *appSettings = [AppSettings sharedInstance];
    // Only set the exit time if the application is currently unlocked
    if (lockWindow.isHidden) {
        [appSettings setExitTime:[NSDate date]];
    }
    [self.pinViewController showPinKeypad:[appSettings pinEnabled]];
    [lockWindow makeKeyAndVisible];
}

@end
