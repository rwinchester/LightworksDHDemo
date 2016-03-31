//
//  ViewController.h
//  LightworksDHDemo
//
//  Created by Rob Winchester on 3/29/16.
//  Copyright © 2016 Digital Lumens. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ShareableSocket.h"
#import <Lumu/Lumu.h>

@interface ViewController : UIViewController <LumuManagerDelegate>

@property (weak, nonatomic) IBOutlet UIButton *fixtureButton;
@property (weak, nonatomic) IBOutlet UISlider *levelSlider;
@property (weak, nonatomic) IBOutlet UILabel *levelLabel;
@property (weak, nonatomic) IBOutlet UILabel *lumuLevelLabel;
@property (weak, nonatomic) IBOutlet UIButton *calibrateButton;

- (IBAction)fixtureButtonPressed:(id)sender;
- (IBAction)calibrateButtonPressed:(id)sender;
- (IBAction)levelSliderChanged:(UISlider*)sender;
- (IBAction)levelSliderDone:(UISlider*)sender;

@end
