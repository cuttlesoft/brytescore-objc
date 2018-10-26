//  BrytescoreAPIManager.m
//  BrytescoreObjcAPI
//
//  Created by Marisa Gomez on 10/16/18.

#import "BrytescoreAPIManager.h"

@implementation BrytescoreAPIManager
// --------------------------------- MARK: static variables --------------------------------- //
// Variables used to fill event data for tracking
static NSString* url = @"https://api.brytecore.com/";
static NSString* packageUrl = @"https://cdn.brytecore.com/packages/";
static NSString* packageName = @"/package.json";
static NSString* hostname = @"com.brytecore.mobile";
static NSString* library = @"iOS";
static NSString* libraryVersion = @"0.1.0";
static NSDictionary* eventNames;

// --------------------------------- MARK: dynamic variables -------------------------------- //
NSString* _apiKey = nil;

// Variables to hold package-wide IDs
NSInteger userId = 0;
NSString* anonymousId = nil;
NSString* sessionId = nil;
NSString* pageViewId = nil;

// Variables used to fill event data for tracking
// When additional packages are loaded, they are added to this dictionary
NSMutableDictionary* schemaVersion;

// Dynamically loaded packages
NSMutableDictionary* packageFunctions;

// Inactivity timers
NSInteger inactivityId = 0;

// Variables for heartbeat timer
NSTimer* heartbeatTimer;
Boolean isHeartbeatTimerRunning = false;
NSTimeInterval heartbeatLength = 15;
NSDate* startHeartbeatTime;
NSTimeInterval totalPageViewTime = 0;

// Variables for mode statuses
Boolean devMode = false;
Boolean debugMode = false;
Boolean impersonationMode = false;
Boolean validationMode = false;

// ---------------------------------- MARK: public methods: --------------------------------- //
/**
 Sets the API key.
 Generates a new unique session ID.
 Retrieves the saved user ID, if any.
 
 - parameter apiKey: The API key.
 */
- (id) initWithAPIKey:(NSString*)apiKey {
     self = [super init];
    if (self) {
        eventNames = @{
                       @"authenticated": @"authenticated",
                       @"brytescoreUUIDCreated": @"brytescoreUUIDCreated",
                       @"heartBeat": @"heartBeat",
                       @"pageView": @"pageView",
                       @"registeredAccount": @"registeredAccount",
                       @"sessionStarted": @"sessionStarted",
                       @"startedChat": @"startedChat",
                       @"submittedForm": @"submittedForm",
                       @"updatedUserInfo": @"updatedUserInfo"
        };
        
        schemaVersion = [NSMutableDictionary new];
        [schemaVersion setObject:@"0.3.1" forKey:@"analytics"];
        packageFunctions = [NSMutableDictionary new];
        heartbeatTimer = [NSTimer new];
        startHeartbeatTime = [NSDate date];
        
        _apiKey = apiKey;
        
        // Generate and save unique session ID
        sessionId = [self generateUUID];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:sessionId forKey:@"brytescore_session_sid"];
        
        // Retrieve user ID from brytescore_uu_uid
        userId = [defaults integerForKey:@"brytescore_uu_uid"];
        
        // Check if we have an existing aid, otherwise generate
        if ([defaults stringForKey:@"brytescore_uu_aid"] != nil) {
            anonymousId = [defaults stringForKey:@"brytescore_uu_aid"];
            NSLog(@"Retrieved anonymous user ID: %@", anonymousId);
        } else {
            anonymousId = [self generateUUID];
            NSLog(@"Generated anonymous user ID: %@", anonymousId);
        }
        
        [defaults setObject:anonymousId forKey:@"brytescore_uu_aid"];
        [defaults synchronize];
    }
    
    return self;
}

/**
 Returns the current API key
 
 - returns: The current API key
 */
- (NSString*) getAPIKey {
    return _apiKey;
}

/**
 Function to load json packages.
 
 - parameter NSString The name of the package.
 */
- (void) load:(NSString*)package {
    NSLog(@"Calling load: %@", package);
    NSLog(@"Loading %@%@%@", packageUrl, package, packageName);

    // Generate the request endpoint
    NSString* requestEndpoint = [NSString stringWithFormat:@"%@%@%@", packageUrl, package, packageName];
    NSURL* url = [NSURL URLWithString:requestEndpoint];
    if (url == nil) {
        NSLog(@"Error: cannot create URL");
        return;
    }

    // Set up the URL request
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    
    // Set up the session
    NSURLSession* session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.defaultSessionConfiguration];
    
    NSURLSessionDataTask* task = [session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        // Check for any explicit errors
        if (error != nil) {
            [self print:[NSString stringWithFormat:@"An error occurred while calling: %@ error: %@", requestEndpoint, error]];
            return;
        }
        
        // Retrieve the HTTP response status code, check that is exists
        if (![response isKindOfClass:[NSHTTPURLResponse class]]) {
            [self print:[NSString stringWithFormat:@"An error occurred while calling: %@", requestEndpoint]];
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        NSInteger statusCode = httpResponse.statusCode;
        
        if (statusCode == 404 || statusCode == 500) {
            [self print:[NSString stringWithFormat:@"An error occurred while calling: %@ error: %lds", requestEndpoint, (long)statusCode]];
            return;
        }
        
        // Check that data was received from the API
        if (data == nil) {
            [self print:[NSString stringWithFormat:@"An error occurred: did not receive data"]];
            return;
        }
        
        // Parse the API response data
        NSError* jsonError;
        NSMutableDictionary* responseJSON = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&jsonError];
        if(jsonError) {
            [self print:[NSString stringWithFormat:@"An error occured while trying to convert data to JSON"]];
            return;
        } else {
            [self print:[NSString stringWithFormat:@"Call successful, response: %@", responseJSON]];
            
            // Get just the events object of the package
            [packageFunctions setObject:[responseJSON objectForKey:@"events"] forKey:package];
            
            // Get the namespace of the package
            NSString* namespace = [responseJSON objectForKey:@"namespace"];
            [schemaVersion setObject:[responseJSON objectForKey:@"version"] forKey:namespace];
        }
    }];
    [task resume];
}

/**
 Sets dev mode.
 Logs events to the console instead of sending to the API.
 Turning on dev mode automatically triggers debug mode.
 
 - parameter enabled: If true, then dev mode is enabled.
 */

- (void) devMode:(Boolean)enabled {
    devMode = enabled;
    
    // If devMode is turned on, debugMode should be too.
    if (devMode) {
        [self debugMode:true];
    }
}

/**
 Sets debug mode.
 Log events are suppressed when debug mode is off.
 
 - parameter enabled: If true, then debug mode is enabled.
 */
- (void) debugMode:(Boolean)enabled {
    debugMode = enabled;
}

/**
 Sets impersonation mode.
 Bypasses sending information to the API when impersonating another user.
 
 - parameter enabled: If true, then impersonation mode is enabled.
 */
- (void) impersonationMode:(Boolean)enabled {
    impersonationMode = enabled;
}

/**
 Sets validation mode.
 Adds a validation attribute to the data for all API calls.
 
 - parameter enabled: If true, then validation mode is enabled.
 */
- (void) validationMode:(Boolean)enabled {
    validationMode = enabled;
}

/**
 *
 */
- (void) brytescore:(NSString*)property withData:(NSMutableDictionary*)data {
    NSLog(@"Calling brytescore: %@", property);
    
    // Ensure that a property is provided
    if (property.length == 0) {
        NSLog(@"Abandon ship! You must provide a tracking property.");
        return;
    }
    
    // Retrieve the namespace and function name, from property of format 'namespace.functionName'
    NSArray* splitPackage = [property componentsSeparatedByString:@"."];
    if (splitPackage.count != 2) {
        NSLog(@"Invalid tracking property name received. Should be of the form: 'namespace.functionName'");
        return;
    }
    NSString* namespace = splitPackage[0];
    NSString* functionName = splitPackage[1];
    
    // Retrieve the function details from the loaded package, ensuring that it exists
    NSMutableDictionary* function = [packageFunctions objectForKey:namespace];
    if (function == nil) {
        NSLog(@"The %@ package is not loaded, or %@ is not a valid function.", namespace, functionName);
        return;
    }
    
    NSMutableDictionary* functionDetails = [function objectForKey:functionName];
    if (functionDetails == nil) {
        NSLog(@"The %@ package is not loaded, or %@ is not a valid function.", namespace, functionName);
        return;
    }
    
    NSString* eventDisplayName = [functionDetails objectForKey:@"displayName"];
    if (eventDisplayName == nil) {
        NSLog(@"The function display name could not be loaded.");
        return;
    }
    
    // Track the validated listing.
    [self track:property withEventDiplayName:eventDisplayName andData:data];
}

/**
 Start a pageView.
 
 - parameter data: The pageView data.
 - data.isImpersonating:
 - data.pageUrl:
 - data.pageTitle:
 - data.referrer:
 */
- (void) pageView:(NSMutableDictionary*)data {
    NSLog(@"Calling pageView: %@", data);
    
    // If the user is being impersonated, do not track.
    if (![self checkImpersonation:data]) {
        return;
    }
    
    totalPageViewTime = 0;
    pageViewId = [self generateUUID];
    
    [self track:[eventNames objectForKey:@"pageView"] withEventDiplayName:@"Viewed a Page" andData:data];
    
    // Save session information
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:sessionId forKey:@"brytescore_session_sid"];
    [defaults setObject:anonymousId forKey:@"brytescore_session_aid"];
    [defaults synchronize];
    
    // Send the first heartbeat and start the timer
    NSLog(@"Sending 'first' heartbeat.");
    [self heartBeat];
    heartbeatTimer = [NSTimer scheduledTimerWithTimeInterval:heartbeatLength target:self selector:@selector(checkHeartbeat) userInfo:nil repeats:true];
}

/**
 Sends a new account registration event.
 
 - parameter data: The registration data.
 - data.isImpersonating
 - data.userAccount.id
 */
- (void) registeredAccount:(NSMutableDictionary*)data {
    NSLog(@"Calling registeredAccount: %@", data);
    Boolean userStatus = [self updateUser:data];
    
    // Finally, as long as the data was valid, track the account registration
    if (userStatus) {
        [self track:[eventNames objectForKey:@"registeredAccount"] withEventDiplayName:@"Created a new account" andData:data];
    }
}

/**
 Sends a submittedForm event.
 
 - parameter data: The chat data.
 - data.isImpersonating
 */
- (void) submittedForm:(NSMutableDictionary*)data {
    // If the user is being impersonated, do not track.
    if (![self checkImpersonation: data]) {
        return;
    }
    
    [self track:[eventNames objectForKey:@"submittedForm"] withEventDiplayName:@"Submitted a Form" andData:data];
}

/**
 Sends a startedChat event.
 
 - parameter data: The form data.
 - data.isImpersonating
 */
- (void) startedChat:(NSMutableDictionary*)data {
    // If the user is being impersonated, do not track.
    if (![self checkImpersonation: data]) {
        return;
    }
    
    [self track:[eventNames objectForKey:@"startedChat"] withEventDiplayName:@"User Started a Live Chat" andData:data];
}

/**
 Updates a user's account information.
 
 - parameter data The account data.
 */
- (void) updatedUserInfo:(NSMutableDictionary*)data {
    NSLog(@"updatedUserInfo: %@", data);
    Boolean userStatus = [self updateUser:data];
    
    // If the user is being impersonated, do not track.
    if (![self checkImpersonation: data]) {
        return;
    }
    
    // Finally, as long as the data was valid, track the user info update
    if (userStatus) {
        [self track:[eventNames objectForKey:@"updatedUserInfo"] withEventDiplayName:@"Updated a User Information" andData:data];
    }
}

/**
 Sends a user authentication event.
 
 - parameter data: The authentication data.
 - data.isImpersonating
 - data.userAccount
 - data.userAccount.id
 */
- (void) authenticated:(NSMutableDictionary*)data {
    // If the user is being impersonated, do not track.
    if (![self checkImpersonation:data]) {
        return;
    }
    
    // Ensure that we have a user Id from data.userAccount.id
    NSMutableDictionary* userAccount = [data objectForKey:@"userAccount"];
    if (userAccount == nil) {
        NSLog(@"data.userAccoutn is not defined");
        return;
    }
    NSInteger newUserId = [[userAccount objectForKey:@"id"] integerValue];
    if (newUserId == 0) {
        NSLog(@"data.userAccount.id is not defined");
        return;
    }
    
    // Check if we have an existing aid, otherwise generate
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:@"brytescore_uu_aid"] != nil) {
        anonymousId = [defaults objectForKey:@"brytescore_uu_aid"];
        NSLog(@"Retrieved anonymous user ID %@", anonymousId);
    } else {
        anonymousId = [self generateUUID];
    }
    
    // Retrieve user Id from brytescore_uu_uid
    NSInteger storedUserId = 0;
    if ([defaults objectForKey:@"brytescore_uu_uid"] != nil) {
        storedUserId = [[defaults objectForKey:@"brytescore_uu_uid"] integerValue];
        NSLog(@"Retrieved user Id: %lds", (long)storedUserId);
    }
    
    // If there is a UID stored locally and the localUID does not match our new UID
    if (storedUserId != 0 && storedUserId != newUserId) {
        [self changeLoggedInUser:newUserId]; // Saves our new user Id to our global user Id
    }
    
    // Save our anonymous Id and user Id to local storage
    [defaults setObject:anonymousId forKey:@"brytescore_uu_aid"];
    [defaults setInteger:userId forKey:@"brytescore_uu_uid"];
    [defaults synchronize];
    
    // Finally, in any case, track the authentication
    [self track:[eventNames objectForKey:@"authenticated"] withEventDiplayName:@"Logged in" andData:data];
}

/**
 * Kills the session.
 */
- (void) killSession {
    NSLog(@"Calling killSession");
    
    // Stop the timer
    [heartbeatTimer invalidate];
    
    // Reset the heartbeat start time
    startHeartbeatTime = [NSDate new];
    
    // Delete and save session id
    sessionId = nil;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:sessionId forKey:@"brytescore_session_sid"];
    [defaults synchronize];
    
    // Reset pageViewIds
    pageViewId = nil;
}

// ---------------------------------- MARK: private methods --------------------------------- //
/**
 Main track function
 
 - parameter eventName: The event name.
 - parameter eventDisplayName: The event display name.
 - parameter data: The event data.
 */
- (void) track:(NSString*)eventName withEventDiplayName:(NSString*)eventDisplayName andData:(NSMutableDictionary*)data {
    NSLog(@"Calling track: %@ %@ %@", eventName, eventDisplayName, data);
    
    // If the user is being impersonated, do not track.
    if (![self checkImpersonation:data]) {
        return;
    }
    
    [self sendRequest:@"track" withEventName:eventName eventDisplayName:eventDisplayName andData:data];
}

/**
 Helper Function for making CORS calls to the API.
 
 - parameter path: path for the API URL
 - parameter eventName: name of the event being tracked
 - parameter eventDisplayName: display name of the event being tracked
 - parameter data: metadate of the event being tracked
 */
- (void) sendRequest:(NSString*)path withEventName:(NSString*)eventName eventDisplayName:(NSString*)eventDisplayName andData:(NSMutableDictionary*)data {
    NSLog(@"Calling sendRequest: %@ %@ %@", path, eventName, eventDisplayName);
    
    // Generate the request endpoint
    NSString* requestEndpoint = [NSString stringWithFormat:@"%@%@", url, path];
    NSURL* requestUrl = [NSURL URLWithString:requestEndpoint];
    if (requestUrl == nil) {
        NSLog(@"Error: cannot create URL");
        return;
    }
    
    if (_apiKey.length == 0) {
        NSLog(@"Abandon ship! You must provide an API key.");
        return;
    }
    
    // Set up the URL request
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:requestUrl];
    [request setHTTPMethod:@"POST"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    // Deduce the schema version (namespace)
    // Check if the property is of the format 'namespace.functionName'
    // If so, replace the namespace
    NSString* namespace = @"analytics";
    NSArray* splitPackage = [path componentsSeparatedByString:@"."];
    if (splitPackage.count == 2) {
        namespace = splitPackage[0];
    }
    
    // Check if sessionId is set, if nil, generae a new one
    if (sessionId == nil) {
        // Generate new sessionId
        sessionId = [self generateUUID];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:sessionId forKey:@"brytescore_session_sid"];
        [defaults synchronize];
    }
    
    /**
     Generate the object to send to the API
     
     - "event"              - param     - eventName
     - "eventDisplayName"   - param     - eventDisplayName
     - "hostName" - static  - static    - custom iOS hostname
     - "apiKey"             - static    - user's API key
     - "anonymousId"        - generated - Brytescore UID
     - "userId"             - retrieved - Client user id, may be null if unauthenticated
     - "pageViewId"         - generated - Brytescore UID
     - "sessionId"          - generated - Brytescore session id
     - "library"            - static    - library type
     - "libraryVersion"     - static    - library version
     - "schemaVersion"      - generated - if eventName contains '.', use a custom schemaVersion based on the eventName. otherwise, use schemaVersion.analytics
     - "data"               - param     - data
     */
    NSMutableDictionary* eventData = [NSMutableDictionary new];
    [eventData setObject:eventName forKey:@"event"];
    [eventData setObject:eventDisplayName forKey:@"eventDisplayName"];
    [eventData setObject:hostname forKey:@"hostName"];
    [eventData setObject:_apiKey forKey:@"apiKey"];
    [eventData setObject:anonymousId ? : @"" forKey:@"anonymousId"];
    [eventData setObject:[NSNumber numberWithInteger:userId] forKey:@"userId"];
    [eventData setObject:[self generateUUID] forKey:@"pageViewId"];
    [eventData setObject:sessionId ? : @"" forKey:@"sessionId"];
    [eventData setObject:library forKey:@"library"];
    [eventData setObject:libraryVersion forKey:@"libraryVersion"];
    [eventData setObject:[schemaVersion objectForKey:namespace] forKey:@"schemaVersion"];
    [eventData setObject:data forKey:@"data"];

    if (validationMode) {
        [eventData setObject:validationMode ? @"true" : @"false" forKey:@"validationOnly"];
    }
    
    // Set up the request body
    NSError* error;
    if ([NSJSONSerialization isValidJSONObject:eventData]) {
        [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:eventData options:NSJSONWritingPrettyPrinted error:&error]];
        
        if (error != nil) {
            NSLog(@"%@", error.localizedDescription);
        }
        
        // Set up the session
        NSURLSession* session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.defaultSessionConfiguration];
        
        // Execute the request
        [self print:[NSString stringWithFormat:@"eventData: %@", eventData]];
        if (!devMode) {
            NSURLSessionDataTask* task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                
                // Check for any explicit errors
                if (error != nil) {
                    NSLog(@"An error occurred while calling: %@, error: %@", requestEndpoint, error);
                    return;
                }
                
                // Retrieve the HTTP response status code, check that it exists
                if (![response isKindOfClass:[NSHTTPURLResponse class]]) {
                    NSLog(@"An error occurred while calling: %@", requestEndpoint);
                    return;
                }
                
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                NSInteger statusCode = httpResponse.statusCode;
                
                if (statusCode == 404 || statusCode == 500) {
                    [self print:[NSString stringWithFormat:@"Response: %@", response]];
                    [self print:[NSString stringWithFormat:@"An error occurred while calling: %@ status: %ld error: %@", requestEndpoint, (long)statusCode, error]];
                    return;
                }
                
                // Check that data was received from the API
                if (data == nil) {
                    [self print:[NSString stringWithFormat:@"An error occurred: did not receive data"]];
                    return;
                }
                
                // Parse the API response data
                NSError* jsonError;
                NSMutableDictionary* responseJSON = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&jsonError];
                if(jsonError) {
                    [self print:[NSString stringWithFormat:@"error trying to convert data to JSON"]];
                    return;
                } else {
                    [self print:[NSString stringWithFormat:@"Call successful, response: %@", responseJSON]];
                }
            }];
            [task resume];
        }
    } else {
        NSLog(@"An error occured while trying to convert data to JSON");
    }
}

/**
 Generate UUID using Objective-C built-in generator
 
 - link: https://developer.apple.com/documentation/foundation/uuid
 - returns: a new UUID string
 */
- (NSString*) generateUUID {
    return [[NSUUID UUID] UUIDString];
}

/**
 Process a change in the logged in user:
 - Kill current session for old user
 - Update and save the global user ID variable
 - Generate and save new anonymousId
 - Generate new sessionId
 
 - parameter userID: The user ID.
 */
- (void) changeLoggedInUser:(NSInteger)userID {
    // Kill current session for old user
    [self killSession];
    
    // Update and save the global user Id variable
    userId = userID;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:sessionId forKey:@"brytescore_uu_uid"];
    
    // Generate and save new anonymousId
    anonymousId = [self generateUUID];
    [defaults setObject:sessionId forKey:@"brytescore_uu_aid"];
    [defaults synchronize];
    
    NSMutableDictionary* idData = [NSMutableDictionary new];
    [idData setObject:anonymousId forKey:@"anonymousId"];
    [self track:[eventNames objectForKey:@"brytescoreUUIDCreated"] withEventDiplayName:@"New user id Created" andData:idData];
    
    // Generate new sessionId
    sessionId = [self generateUUID];
    
    NSMutableDictionary* sessionData = [NSMutableDictionary new];
    [sessionData setObject:sessionId forKey:@"sessionId"];
    [sessionData setObject:anonymousId forKey:@"anonymousId"];
    [self track:[eventNames objectForKey:@"sessionStarted"] withEventDiplayName:@"started new session" andData:sessionData];
    
    // Page view will update session cookie no need to write one.
    [self pageView:[NSMutableDictionary new]];
}

/**
 * Sends a heartbeat event
 */
- (void) heartBeat {
    NSLog(@"Calling heartBeat");
    
    totalPageViewTime = totalPageViewTime + heartbeatLength;
    
    NSMutableDictionary* heartbeatData = [NSMutableDictionary new];
    NSNumber *pageViewTime = [[NSNumber alloc] initWithDouble:totalPageViewTime];
    [heartbeatData setValue:pageViewTime forKey:@"elapsedTime"];
    [self track:[eventNames objectForKey:@"heartBeat"] withEventDiplayName:@"Heartbeat" andData:heartbeatData];
}

/**
 - Ensure that the user is not being impersonated
 - Ensure that we have a user ID in the data parameter
 - Update the global `userId` if it is not accurate
 */
- (Boolean) updateUser:(NSMutableDictionary*)data {
    // If the user is being impersonated, do not track.
    if (![self checkImpersonation:data]) {
        return false;
    }
    
    // Ensure that we have a user Id from data.userAccount.id
    NSMutableDictionary* userAccount = [data objectForKey:@"userAccount"];
    if (userAccount == nil) {
        NSLog(@"data.userAccount is not defined");
    }
    
    NSInteger localUserId = [[userAccount objectForKey:@"id"] integerValue];
    if (localUserId == 0) {
        NSLog(@"data.userAccount.id is not defined");
    }
    
    // If we haven't saved the user Id globally, or the user Ids do not match
    if (userId == 0 || localUserId != userId) {
        // Retrieve anonymous user Id from brytescore_uu_aid, or generate a new anonymous user Id
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        anonymousId = [defaults objectForKey:@"brytescore_uu_aid"];
        if (anonymousId == nil) {
            NSLog(@"No anonymous Id has been saved. Generating...");
            anonymousId = [self generateUUID];
            NSLog(@"Generated new anonymous user Id: %@", anonymousId);
            
            NSMutableDictionary* data = [NSMutableDictionary new];
            [data setObject:anonymousId forKey:@"anonymousId"];
            [self track:[eventNames objectForKey:@"brytescoreUUIDCreated"] withEventDiplayName:@"New user id Created" andData:data];
        } else {
            NSLog(@"Retrieved anonymous user Id: %@", anonymousId);
        }
        
        // Save our new user Id to our global userId
        userId = localUserId;
        
        // Save our anonymous Id and user Id to local storage
        [defaults setObject:anonymousId forKey:@"brytescore_uu_aid"];
        [defaults setInteger:userId forKey:@"brytescore_uu_uid"];
        [defaults synchronize];
    }
    return true;
}

/**
 *
 */
- (Boolean) checkImpersonation:(NSMutableDictionary*)data {
    if (impersonationMode || [data objectForKey:@"impersonationMode"] != nil) {
        NSLog(@"Impersonation mode is on - will not track event");
        return false;
    }
    
    return true;
}

/**
 *
 */
- (void) checkHeartbeat {
    NSLog(@"Calling checkHeartbeat");
    
    NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:startHeartbeatTime];

    NSLog(@"elapsed: %f", elapsed);
    // Heartbeat is not dead yet.
    if (elapsed < 1800) {
        NSLog(@"Heartbeat is not dead yet.");
        startHeartbeatTime = [NSDate date];
        [self heartBeat];
    } else {
        //Heartbeat is dead
        NSLog(@"Heartbeat is dead.");
        [self killSession];
    }
}

/**
 Custom print function to only print while in debugMode
 */
- (void) print:(NSString*)item {
    if (debugMode) {
        NSLog(@"%@", item);
    }
}
@end
