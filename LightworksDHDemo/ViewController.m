//
//  ViewController.m
//  LightworksDHDemo
//
//  Created by Rob Winchester on 3/29/16.
//  Copyright © 2016 Digital Lumens. All rights reserved.
//

#import "ViewController.h"
#import "Node.h"
#import "ShareableSocket.h"

@interface ViewController ()

@property NSString *nodeNameStr;
@property NSString *nodeSnStr;
@property NSMutableData *responseData;
@property bool connected;
@property int mode;
@property NSMutableArray *nodesArray;
- (void)connectToServer;

@end


@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    _connected = false;
    _mode = 0;

    [self connectToServer];

    [LumuManager sharedManager].delegate = self;
    [[LumuManager sharedManager] startLumuManager];

    // Engineering 4.4 (06001234)
    _nodeNameStr = @"Engineering 4.4";
    _nodeSnStr = @"06002295";

    _levelSlider.enabled = NO;
    _levelLabel.enabled = NO;
    _levelLabel.text = @"";

    [_fixtureButton setTitle:[NSString stringWithFormat:@"%@ (%@)", _nodeNameStr, _nodeSnStr] forState:UIControlStateNormal];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark Wamp Methods

- (void)connectToServer {
    ShareableSocket *socket = [ShareableSocket instance];
    [socket createSession:self];
    _mode = 1;
    [socket connect];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
                                 didReceiveResponse:(NSURLResponse *)response
                                  completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {

    NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
    if ([httpResponse statusCode] == 200) {
        _responseData=nil;
        _responseData=[[NSMutableData alloc] init];
        [_responseData setLength:0];
    } else {
        NSLog(@"Response: %@", response);
    }

    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
   didReceiveData:(NSData *)data {

    [_responseData appendData:data];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    switch (_mode) {
        case 1:
            [self connectCompleted: error];
            break;
        case 2:
            [self getNodesCompleted: error];
            break;
    }
}

- (void)connectCompleted:(NSError *)error {
    if (error) {
        NSLog(@"Error trying to connect: %@", error);
    } else {
        NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:_responseData options:NSJSONReadingMutableLeaves error:nil];
        if (error == nil) {
            for (id key in dic) {
                id value = [dic objectForKey:key];
                NSString *keyAsString = (NSString *)key;
                NSString *valueAsString = (NSString *)value;
                if (keyAsString != NULL) {
                    if([keyAsString isEqual: @"access_token"]) {
                        ShareableSocket *socket = [ShareableSocket instance];
                        socket.auth_token = [NSString stringWithFormat:@"%@", valueAsString];
                        _connected = true;
                        NSLog(@"Connected");
                        if (_mode == 1) {
                            _mode = 2;
                            [socket getNodes];
                        }
                        [self beginWamp];
                    }
                } else {
                    NSLog(@"No access_token found");
                }
            }
        } else {
            NSLog(@"Error: %@", error);
        }
    }
}

- (void)getNodesCompleted:(NSError *)error {
    if (error == nil) {
        NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:_responseData options:NSJSONReadingMutableLeaves error:nil];
        if (error == nil) {
            NSArray *rawArray = [dic valueForKey:@"data"];
            _nodesArray = [[NSMutableArray alloc] init];

            dispatch_async(dispatch_get_main_queue(), ^{
                for (id obj in rawArray) {
                    Node *node = [Node alloc];
                    NSDictionary *attributes = [obj valueForKey: @"attributes"];
                    NSString *xStr = [attributes valueForKey: @"pos_x"];
                    NSString *yStr = [attributes valueForKey: @"pos_y"];
                    node.x = [xStr floatValue];
                    node.y = [yStr floatValue];
                    node.idStr = [obj valueForKey: @"id"];
                    node.nameStr = [attributes valueForKey: @"name"];
                    NSString *snStr = [attributes valueForKey: @"sn"];
                    unsigned long long sn = [snStr longLongValue];
                    node.snStr = [NSString stringWithFormat:@"%08llx", sn];
                    NSObject *relationships = [obj valueForKey: @"relationships"];
                    NSObject *leafGroup = [relationships valueForKey: @"leaf_group"];
                    NSObject *leafGroupData = [leafGroup valueForKey: @"data"];
                    node.leafGroupIdStr = [leafGroupData valueForKey: @"id"];
                    [_nodesArray addObject:node];
                }
                NSLog(@"Found %lu nodes in db", (unsigned long)[_nodesArray count]);

                [self performSelector:NSSelectorFromString(@"selectNode") withObject:nil afterDelay:0.0];
            });
        } else {
            NSLog(@"Error: %@", error);
        }
    } else {
        NSLog(@"Error: %@", error);
    }
}


- (void)selectNode {

    BOOL found = NO;
    for (Node *node in _nodesArray) {
        if ([node.snStr isEqualToString:_nodeSnStr]) {
            found = YES;
            ShareableSocket *socket = [ShareableSocket instance];
            [socket getOverride:node.leafGroupIdStr complete:^(MDWampResult *result, NSError *error) {
                if (error == nil) {
                    NSArray *values = [result.argumentsKw allValues];
                    NSNumber *level = [values objectAtIndex:1];
                    _levelSlider.enabled = YES;
                    _levelLabel.enabled = YES;
                    _levelSlider.value = [level intValue];
                    _levelLabel.text = [NSString stringWithFormat:@"%d", [level intValue]];
                } else {
                    NSLog(@"getOverride Error: %@", error.description);
                }
            }];
        }
    }
    if (found == NO) {
        NSLog(@"Couldn't find %@", _nodeSnStr);
    }
}


- (void)beginWamp {
    ShareableSocket *socket = [ShareableSocket instance];
    [socket connectWamp];
}


- (void)shareableSocketDidReceiveEvent:(NSData *)eventData {
}

- (void)shareableSocketDidReceiveHarvesterData:(NSData *)harvesterData {
}

- (void)shareableSocketDidReceiveGroupOverride:(NSData *)groupOverrideData {
}

#pragma mark Lumu Methods

-(void)lumuManagerDidNotRecognizeLumu {
    _lumuLevelLabel.text = @"Insert Lumu";
}

-(void)lumuManagerDidReceiveData: (CGFloat)value {
    _lumuLevelLabel.text = [NSString stringWithFormat:@"%.0f lux", value];
}

-(void)lumuManagerDidStopLumu {
    _lumuLevelLabel.text = @"Insert Lumu";
}

#pragma mark View Methods

- (IBAction)levelSliderChanged:(UISlider*)sender {

    int i = roundl([sender value]);
    _levelLabel.text = [NSString stringWithFormat:@"%d", i];
}

- (IBAction)levelSliderDone:(UISlider*)sender {

    for (Node *node in _nodesArray) {
        if ([node.snStr isEqualToString:_nodeSnStr]) {
            int level = roundl([sender value]);
            ShareableSocket *socket = [ShareableSocket instance];
            [socket setOverride:level withLock:false forId:node.leafGroupIdStr complete:^(MDWampResult *result, NSError *error) {
                if (error == nil) {
                    NSLog(@"levelSliderDone");
                } else {
                    NSLog(@"getOverride Error: %@", error.description);
                }
            }];
        }
    }
}

- (IBAction)calibrateButtonPressed:(id)sender {
    // dh_begin_cal  // cache ramps+dh+inactive, set ramps: off, dh: off, inactive: current active
    // dh_get_sensor // return ambient light level (0x0059)
    // dh_save_cal   // store all 5 dh values (passed as params however you like)
    // dh_end_cal    // restore ramps+dh+inactive
}

- (IBAction)fixtureButtonPressed:(id)sender {
    NSLog(@"fixtureButtonPressed");
}

@end
