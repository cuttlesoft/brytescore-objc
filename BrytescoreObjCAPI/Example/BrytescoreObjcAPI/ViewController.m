//
//  BrytescoreObjcAPIViewController.m
//  BrytescoreObjcAPI
//
//  Created by mcgomez on 10/16/2018.
//  Copyright (c) 2018 mcgomez. All rights reserved.
//

#import "ViewController.h"


@interface BrytescoreObjcAPIViewController ()

@end

@implementation BrytescoreObjcAPIViewController
// ------------------------------------- MARK: Variables ------------------------------------ //
// Initialize the API Manager with your API key.
BrytescoreAPIManager* apiManager;

// Bools for local status of dev and debug mode, used to toggle state with buttons
Boolean devMode = false;
Boolean debugMode = true;
Boolean impersonationMode = false;
Boolean validationMode = false;

// Button helpers - API Key label and button colors
NSString* defaultAPIKeyLabel = @"Your API Key:";
UIColor* blue;
UIColor* green;
UIColor* orange;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    apiManager = [[BrytescoreAPIManager alloc] initWithAPIKey:@"abc123"];
    
	blue = [UIColor colorWithRed:0.15 green:0.66 blue:0.88 alpha:0.8];
    green = [UIColor colorWithRed:0.46 green:0.71 blue:0.24 alpha:0.8];
    orange = [UIColor colorWithRed:0.87 green:0.53 blue:0.20 alpha:0.8];
    
    // Enable dev mode - logs API calls instead of making HTTP request
    [apiManager devMode:devMode];
    char* devModeOn = devMode ? "Off" : "On";
    [_toggleDevModeButton setTitle:[NSString stringWithFormat:@"Toggle Dev Mode: Turn %s", devModeOn] forState:UIControlStateNormal];
    UIColor* devModeBackground = devMode ? orange : green;
    [_toggleDevModeButton setBackgroundColor:devModeBackground];
    
    // Enable debug mode - turns on console logs
    [apiManager debugMode:debugMode];
    [apiManager load:@"realestate"];
    char* debugModeOn = debugMode ? "Off" : "On";
    [_toggleDebugModeButton setTitle:[NSString stringWithFormat:@"Toggle Debug Mode: Turn %s", debugModeOn] forState:UIControlStateNormal];
    UIColor* debugModeBackground = debugMode ? orange : green;
    [_toggleDebugModeButton setBackgroundColor:debugModeBackground];
    
    // Set button colors for unused modes
    UIColor* impersonationModeBackground = impersonationMode ? orange : green;
    UIColor* validationModeBackground = validationMode ? orange : green;
    [_toggleImpersonationModeButton setBackgroundColor:impersonationModeBackground];
    [_toggleValidationModeButton setBackgroundColor:validationModeBackground];
    
    // Update the API Key label to show our API key for debugging
    [_apiKeyLabel setText:[NSString stringWithFormat:@"%@ %@", defaultAPIKeyLabel, [apiManager getAPIKey]]];
    
    // Background listener
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appMovedToBackground) name:UIApplicationWillResignActiveNotification object:nil];
    
    // Foreground listener
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appMovedToForeground) name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void) appMovedToBackground {
    [apiManager killSession];
}

- (void) appMovedToForeground {
    [apiManager pageView:[NSMutableDictionary new]];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// -------------------------------------- MARK: Actions ------------------------------------- //
/**
 Example usage of tracking a page view
 - parameter sender: UIButton
 */
- (IBAction)trackPageView:(id)sender {
    [apiManager pageView:[NSMutableDictionary new]];
}

/**
 Example usage of tracking an account registration
 - parameter sender: UIButton
 */
- (IBAction)trackRegisteredAccount:(id)sender {
    NSDictionary* registrationData = @{
        @"isLead": @false,
        @"userAccount": @{
            @"id": @2
        }
    };
    [apiManager registeredAccount:[registrationData mutableCopy]];
}

/**
 Example usage of tracking authentication
 - parameter sender: UIButton
 */
- (IBAction)trackAuthenticated:(id)sender {
    NSDictionary* authenticatedData = @{
        @"userAccount": @{
            @"id": @2
        }
    };
    [apiManager authenticated:[authenticatedData mutableCopy]];
}

/**
 Example usage of tracking a submitted form
 - parameter sender: UIButton
 */
- (IBAction)trackSubmittedForm:(id)sender {
    NSDictionary* submittedFormData = @{
        @"userAccount": @{
            @"id": @2
        }
    };
    [apiManager submittedForm:[submittedFormData mutableCopy]];
}

/**
 Example usage of tracking the start of a chat
 - parameter sender: UIButton
 */
- (IBAction)trackStartedChat:(id)sender {
    NSDictionary* startedChatData = @{
        @"userAccount": @{
            @"id": @2
        }
    };
    [apiManager startedChat:[startedChatData mutableCopy]];
}

/**
 Example usage of tracking when a user updates their information
 - parameter sender: UIButton
 */
- (IBAction)trackUpdatedUserInfo:(id)sender {
    NSDictionary* updatedUserInfoData = @{
        @"userAccount": @{
            @"id": @2
        }
    };
    [apiManager updatedUserInfo:[updatedUserInfoData mutableCopy]];
}

- (IBAction)trackREViewedListing:(id)sender {
    NSDictionary* viewedListingData = @{
        @"price": @123456,
        @"mls_id": @"string",
        @"street_address": @"string",
        @"street_address_2": @"string",
        @"city": @"string",
        @"state_province": @"string",
        @"postal_code": @"string",
        @"latitude": @"string",
        @"longitude": @"string"
    };
    [apiManager brytescore:@"realestate.viewedListing" withData:[viewedListingData mutableCopy]];
}

/**
 Toggle devMode bool, pass to _apiManager, update button title and color
 
 - parameter sender: UIButton
 */
- (IBAction)toggleDevMode:(id)sender {
    devMode = !devMode;
    [apiManager devMode:devMode];
    char* devModeOn = devMode ? "Off" : "On";
    [sender setTitle:[NSString stringWithFormat:@"Toggle Dev Mode: Turn %s", devModeOn] forState:UIControlStateNormal];
    UIColor* devModeBackground = devMode ? orange : green;
    [sender setBackgroundColor:devModeBackground];
    
    // If devMode is now on and debugMode was off, debugMode is now on.
    // Only update if debugMode wasn't already on.
    if (devMode && !debugMode) {
        debugMode = true;
        [_toggleDebugModeButton setTitle:[NSString stringWithFormat:@"Toggle Debug Mode: Turn Off"] forState:UIControlStateNormal];
        [_toggleDebugModeButton setBackgroundColor:orange];
    }
}

/**
 Toggle debugMode bool, pass to _apiManager, update button title and color
 
 - parameter sender: UIButton
 */
- (IBAction)toggleDebugMode:(id)sender {
    debugMode = !debugMode;
    [apiManager debugMode:debugMode];
    char* debugModeOn = debugMode ? "Off" : "On";
    [sender setTitle:[NSString stringWithFormat:@"Toggle Debug Mode: Turn %s", debugModeOn] forState:UIControlStateNormal];
    UIColor* debugModeBackground = debugMode ? orange : green;
    [sender setBackgroundColor:debugModeBackground];
}

/**
 Toggle impersonationMode bool, pass to _apiManager, update button title and color
 
 - parameter sender: UIButton
 */
- (IBAction)toggleImpersonationMode:(id)sender {
    impersonationMode = !impersonationMode;
    [apiManager impersonationMode:impersonationMode];
    char* impersonationModeOn = impersonationMode ? "Off" : "On";
    [sender setTitle:[NSString stringWithFormat:@"Toggle Impersonation Mode: Turn %s", impersonationModeOn] forState:UIControlStateNormal];
    UIColor* impersonationModeBackground = impersonationMode ? orange : green;
    [sender setBackgroundColor:impersonationModeBackground];
}

/**
 Toggle validationMode bool, pass to _apiManager, update button title and color
 
 - parameter sender: UIButton
 */
- (IBAction)toggleValidationMode:(id)sender {
    validationMode = !validationMode;
    [apiManager validationMode:validationMode];
    char* validationModeOn = validationMode ? "Off" : "On";
    [sender setTitle:[NSString stringWithFormat:@"Toggle Validation Mode: Turn %s", validationModeOn] forState:UIControlStateNormal];
    UIColor* validationModeBackground = validationMode ? orange : green;
    [sender setBackgroundColor:validationModeBackground];
}

@end
