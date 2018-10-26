//  BrytescoreObjcAPIViewController.h
//  BrytescoreObjcAPI
//
//  Created by mcgomez on 10/16/2018.
//  Copyright (c) 2018 mcgomez. All rights reserved.

@import UIKit;
@import BrytescoreObjcAPI;

@interface BrytescoreObjcAPIViewController : UIViewController

// ------------------------------------ MARK: Properties ------------------------------------ //
@property (weak, nonatomic) IBOutlet UILabel *apiKeyLabel;
@property (weak, nonatomic) IBOutlet UIButton *toggleDevModeButton;
@property (weak, nonatomic) IBOutlet UIButton *toggleDebugModeButton;
@property (weak, nonatomic) IBOutlet UIButton *toggleImpersonationModeButton;
@property (weak, nonatomic) IBOutlet UIButton *toggleValidationModeButton;

@end
