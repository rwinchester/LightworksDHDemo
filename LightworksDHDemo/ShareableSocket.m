//
//  ShareableSocket.m
//  LW.03objc
//
//  Created by Rob Winchester on 8/13/15.
//  Copyright © 2015 Digital Lumens. All rights reserved.
//

#import "ShareableSocket.h"

@implementation ShareableSocket

static ShareableSocket *sharedSocket = nil;

struct {
  unsigned int shareableSocketDidReceiveEvent:1;
  unsigned int shareableSocketDidReceiveHarvesterData:1;
  unsigned int shareableSocketDidReceiveGroupOverride:1;
} delegateRespondsTo;

+ (id)instance {
    @synchronized(self) {
        if (sharedSocket == nil) {
            sharedSocket = [[ShareableSocket alloc] init];
        }
    }
    return sharedSocket;
}

- (void)setDelegate:(id <ShareableSocketDelegate>)aDelegate {
    if (_delegate != aDelegate) {
        _delegate = aDelegate;
        delegateRespondsTo.shareableSocketDidReceiveEvent = [_delegate respondsToSelector:@selector(shareableSocketDidReceiveEvent:)];
        delegateRespondsTo.shareableSocketDidReceiveHarvesterData = [_delegate respondsToSelector:@selector(shareableSocketDidReceiveHarvesterData:)];
        delegateRespondsTo.shareableSocketDidReceiveGroupOverride = [_delegate respondsToSelector:@selector(shareableSocketDidReceiveGroupOverride:)];
        NSLog(@"respondsToSelector shareableSocketDidReceiveEvent is %d", delegateRespondsTo.shareableSocketDidReceiveEvent);
        NSLog(@"respondsToSelector shareableSocketDidReceiveHarvesterData is %d", delegateRespondsTo.shareableSocketDidReceiveHarvesterData);
        NSLog(@"respondsToSelector shareableSocketDidReceiveGroupOverride is %d", delegateRespondsTo.shareableSocketDidReceiveGroupOverride);
    }
}

- (void)mdwamp:(MDWamp*)wamp sessionEstablished:(NSDictionary*)info {
    NSLog(@"wamp sessionEstablished");
}


- (void) mdwamp:(MDWamp *)wamp closedSession:(NSInteger)code reason:(NSString*)reason details:(NSDictionary *)details {
    NSLog(@"wamp closedSession: %@", reason);
    NSLog(@"details: %@", details);
}

- (void)disconnect {
    [_wamp disconnect];
}

- (void)createSession:(id)delegate {
    [self setDelegate: delegate];
    _sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    _session = [NSURLSession sessionWithConfiguration:_sessionConfig
                                             delegate:delegate
                                        delegateQueue:nil];
}

- (void)connect {

    if (_session == NULL) { NSLog(@"Error: No session to connect"); return; }

    NSURL *url = [NSURL URLWithString:@"https://dilla.lightrules.net:8445/api/v1/auth/user"];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    NSString *jsonString = [NSString stringWithFormat:@"{ \"organization\":\"digital-lumens\", \"email\": \"rwinchester@digitallumens.com\", \"password\": \"%@\" }", @"testtest"];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-type"];
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[jsonString length]] forHTTPHeaderField:@"Content-length"];
    [request setHTTPBody:[jsonString dataUsingEncoding:NSUTF8StringEncoding]];

    NSURLSessionDataTask *task = [_session dataTaskWithRequest:request];
    [task resume];
}


- (void)getNodes {

    NSLog(@"getNodes");
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://dilla.lightrules.net:8445/api/v1/nodes"]];

    [request setHTTPMethod: @"GET" ];
    [request setValue:@"application/vnd.api+json" forHTTPHeaderField:@"Content-type"];
    NSString *bearer_auth_token = [NSString stringWithFormat:@"Bearer %@", _auth_token];
    [request setValue:bearer_auth_token forHTTPHeaderField:@"Authorization"];
    //[request setHTTPBody: dataifneeded ];

    NSURLSessionDataTask *task = [_session dataTaskWithRequest:request];
    [task resume];
}

#pragma mark Wamp

-(BOOL)connectWamp {
    if ((_wamp == nil || !_wamp.isConnected) && !self.connecting) {
        self.connecting = true;
        MDWampTransportWebSocket *websocket = [[MDWampTransportWebSocket alloc] initWithServer:[NSURL URLWithString:@"wss://lwdev2.lightrules.net:8444/"] protocolVersions:@[kMDWampProtocolWamp2msgpack, kMDWampProtocolWamp2json]];
        _wamp = [[MDWamp alloc] initWithTransport:websocket realm:@"com.digitallumens" delegate:self];
        MDWampClientConfig *conf = [[MDWampClientConfig alloc] init];
        conf.authmethods = @[@"ticket"];
        conf.authid = @"no_id";
        if (_auth_token == nil) {
            NSLog(@"Connect failed: auth_token not set");
        }
        conf.ticket = _auth_token;
        [_wamp setConfig:conf];
        [_wamp connect];
    }
    return TRUE;
}

-(BOOL)disconnectWamp {
    if (_wamp != nil || _wamp.isConnected) {
        [_wamp disconnect];
    }
    return TRUE;
}

- (void)subscribeToNodeEvents {
    [_wamp subscribe:@"com.digitallumens.lightworks.events" onEvent:^(MDWampEvent *payload) {
        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload.argumentsKw options:0 error:&error];
        if (delegateRespondsTo.shareableSocketDidReceiveEvent) {
            [_delegate shareableSocketDidReceiveEvent:jsonData];
        }
    } result:^(NSError *error) {
        if (error) {
            NSLog(@"subscribeToNodeEvents failed: %@", error);
        }
    }];
}

- (void)subscribeToDataHarvesterMessages {
    [_wamp subscribe:@"com.digitallumens.lightworks.data" onEvent:^(MDWampEvent *payload) {
         NSError *error;
         NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload.arguments options:0 error:&error];
         if (delegateRespondsTo.shareableSocketDidReceiveHarvesterData) {
             [_delegate shareableSocketDidReceiveHarvesterData:jsonData];
         }
    } result:^(NSError *error) {
        if (error) {
            NSLog(@"subscribeToDataHarvesterMessages failed: %@", error);
        }
    }];
}

- (void)subscribeToGroupOverrides {
    [_wamp subscribe:@"com.digitallumens.client-service.group.override" onEvent:^(MDWampEvent *payload) {
         NSError *error;
         NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload.argumentsKw options:0 error:&error];
         if (delegateRespondsTo.shareableSocketDidReceiveGroupOverride) {
             [_delegate shareableSocketDidReceiveGroupOverride:jsonData];
         }
    } result:^(NSError *error) {
        if (error) {
            NSLog(@"subscribeToGroupOverrides failed: %@", error);
        }
    }];
}

- (void)sendJSON:(NSString*)message complete:(void(^)(MDWampResult *result, NSError *error))completeBlock {

    NSData *jsonData = [message dataUsingEncoding:NSUTF8StringEncoding];
    NSError *e = nil;
    NSMutableArray *json = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&e];
    // NSLog(@"%@", json);

    [_wamp call:@"com.digitallumens.lightworks.gateway-02020014" args:json kwArgs:nil options:nil complete:completeBlock];
}

- (void)getInitialNodeState:(void(^)(MDWampResult *result, NSError *error))completeBlock {

    NSString *kwArgsString = [NSString stringWithFormat: @"{ \"token\":\"%@\", \"id\": \"%@\", \"procedure\": \"getStateMap\", \"params\": %@ }", _auth_token, @"x", @"null"];
    NSData *data = [kwArgsString dataUsingEncoding:NSUTF8StringEncoding];
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];

    [_wamp call:@"com.digitallumens.client-service.state" args:nil kwArgs:json options:nil complete:completeBlock];
}

- (void)getOverrideMap :(void(^)(MDWampResult *result, NSError *error))completeBlock {

    NSString *kwArgsString = [NSString stringWithFormat: @"{ \"token\":\"%@\", \"procedure\": \"getOverrideMap\", \"params\": %@ }", _auth_token, @"null"];
    NSData *data = [kwArgsString dataUsingEncoding:NSUTF8StringEncoding];
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];

    [_wamp call:@"com.digitallumens.client-service.group" args:nil kwArgs:json options:nil complete:completeBlock];
}

- (void)getOverride:(NSString*)nodeIdStr complete:(void(^)(MDWampResult *result, NSError *error))completeBlock {

    NSString *kwArgsString = [NSString stringWithFormat: @"{ \"token\":\"%@\", \"procedure\": \"getOverride\", \"id\": \"%@\", \"params\": %@ }", _auth_token, nodeIdStr, @"null"];
    NSData *data = [kwArgsString dataUsingEncoding:NSUTF8StringEncoding];
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    [_wamp call:@"com.digitallumens.client-service.group" args:nil kwArgs:json options:nil complete:completeBlock];
}

- (void)setOverride:(int)level withLock:(BOOL)locked forId:(NSString*)nodeIdStr complete:(void(^)(MDWampResult *result, NSError *error))completeBlock {
    NSString *lockStr = @"false";
    if (locked == TRUE) {
        lockStr = @"true";
    }
    NSString *kwArgsString = [NSString stringWithFormat: @"{ \"token\":\"%@\", \"procedure\": \"setOverride\", \"id\":\"%@\", \"params\": {\"level\":%d, \"locked\":%@} }", _auth_token, nodeIdStr, level, lockStr];
    NSData *data = [kwArgsString dataUsingEncoding:NSUTF8StringEncoding];
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    NSLog(@"%@", json);
    [_wamp call:@"com.digitallumens.client-service.group" args:nil kwArgs:json options:nil complete:completeBlock];
}

@end
