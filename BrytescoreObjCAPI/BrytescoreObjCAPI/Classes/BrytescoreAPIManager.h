//  BrytescoreAPIManager.h
//  BrytescoreObjcAPI
//
//  Created by Marisa Gomez on 10/16/18.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BrytescoreAPIManager : NSObject

- (id) initWithAPIKey:(NSString*)apiKey;
- (NSString*) getAPIKey;
- (void) load:(NSString*)package;
- (void) devMode:(Boolean)enabled;
- (void) debugMode:(Boolean)enabled;
- (void) impersonationMode:(Boolean)enabled;
- (void) validationMode:(Boolean)enabled;
- (void) brytescore:(NSString*)property withData:(NSMutableDictionary*)data;
- (void) pageView:(NSMutableDictionary*)data;
- (void) registeredAccount:(NSMutableDictionary*)data;
- (void) submittedForm:(NSMutableDictionary*)data;
- (void) startedChat:(NSMutableDictionary*)data;
- (void) updatedUserInfo:(NSMutableDictionary*)data;
- (void) authenticated:(NSMutableDictionary*)data;
- (void) killSession;

@end

NS_ASSUME_NONNULL_END
