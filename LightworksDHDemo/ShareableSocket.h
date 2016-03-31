//
//  ShareableSocket.h
//  LW.03objc
//
//  Created by Rob Winchester on 8/13/15.
//  Copyright © 2015 Digital Lumens. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MDWamp.h"
#import "MDWampClientDelegate.h"
#import "SRWebSocket.h"

@protocol ShareableSocketDelegate <NSObject>
@optional
- (void)shareableSocketDidReceiveEvent:(NSData *)eventData;
- (void)shareableSocketDidReceiveHarvesterData:(NSData *)harvesterData;
- (void)shareableSocketDidReceiveGroupOverride:(NSData *)overrideData;
@end

@interface ShareableSocket : NSObject <MDWampClientDelegate>

@property (nonatomic, weak) id <ShareableSocketDelegate> delegate;
@property (strong, retain) SRWebSocket *srwebsocket;
@property (strong, retain) MDWampTransportWebSocket *wampSocket;
@property (strong, retain) MDWamp *wamp;
@property (nonatomic) BOOL connecting;

@property NSURLSessionConfiguration *sessionConfig;
@property NSURLSession *session;
@property NSString *auth_token;


+ (id)instance;
- (void)setDelegate:(id <ShareableSocketDelegate>)aDelegate;
- (void)createSession:(id)delegate;
- (void)connect;
- (void)disconnect;
- (void)getNodes;
- (void)subscribeToNodeEvents;
- (void)subscribeToDataHarvesterMessages;
- (void)subscribeToGroupOverrides;

- (BOOL)connectWamp;
- (BOOL)disconnectWamp;
- (void)getInitialNodeState:(void(^)(MDWampResult *result, NSError *error))completeBlock;
- (void)getOverrideMap:(void(^)(MDWampResult *result, NSError *error))completeBlock;
- (void)getOverride:(NSString*)nodeIdStr complete:(void(^)(MDWampResult *result, NSError *error))completeBlock;
- (void)setOverride:(int)level withLock:(BOOL)locked forId:(NSString*)nodeIdStr complete:(void(^)(MDWampResult *result, NSError *error))completeBlock;


- (void)mdwamp:(MDWamp*)wamp sessionEstablished:(NSDictionary*)info;
- (void)mdwamp:(MDWamp*)wamp closedSession:(NSInteger)code reason:(NSString*)reason details:(NSDictionary *)details;

- (void)sendJSON:(NSString*)message complete:(void(^)(MDWampResult *result, NSError *error))completeBlock;

@end
