//
//  PSAppDelegate.h
//  PonyScript
//
//  Created by Steve White on 9/8/12.
//  Copyright (c) 2012 Steve White. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PSViewController;

@interface PSAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) PSViewController *viewController;

@end
