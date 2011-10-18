//
//  SLSMoleculeWebDetailViewController.h
//  Molecules
//
//  Created by Brad Larson on 4/30/2011.
//  Copyright 2011 Sunset Lake Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface SLSMoleculeWebDetailViewController : UIViewController <UIWebViewDelegate>
{
	UIWebView *webDetailView;
    NSURL *moleculeDetailWebPageURL;
    
    UIActivityIndicatorView *loadingActivityIndicator;
}

@property (strong, nonatomic) NSURL *moleculeDetailWebPageURL;

// Initialization and teardown
- (id)initWithURL:(NSURL *)moleculeWebPageURL;

// Web navigation
- (void)goBackInWebView;


@end
