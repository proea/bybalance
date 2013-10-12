//
//  BBBaseViewController.m
//  ByBalance
//
//  Created by Andrew Sinkevitch on 17/06/2012.
//  Copyright (c) 2012 sinkevitch.name. All rights reserved.
//

#import "BBBaseViewController.h"
#import "MBProgressHUD.h"

@interface BBBaseViewController ()

@end


@implementation BBBaseViewController

#pragma mark - View lifecycle

- (void) viewDidLoad
{
	[super viewDidLoad];
	
	//waitIndicator = (DSBezelActivityView *) [[DSBezelActivityView alloc] initForViewAsInstance:self.view withLabel:@"" width:1];
    hud = [[MBProgressHUD alloc] initWithView:self.view];
    [self setupNavBar];
}

- (void) viewDidUnload
{
    [self cleanup];
    
    [super viewDidUnload];
}

/*
- (void) dealloc
{
	[self cleanup];
	
	[super dealloc];
}
 */


- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void) didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}


#pragma mark - Actions
//
- (IBAction) onNavButtonLeft:(id)sender
{
	//to override
}

- (IBAction) onNavButtonRight:(id)sender
{
	//to override
}



#pragma mark - Core logic
//
- (void) cleanup
{
	// DO NOT FORGET CALL [SUPER CLEANUP] IF OVERRIDING ME!!
	
    //remove observers
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
	
    /*
	if (waitIndicator)
	{
		[self showWaitIndicator: NO];
		[waitIndicator release];
		waitIndicator = nil;
	}
     */
}

- (void) showWaitIndicator:(BOOL) aFlag
{
	if (aFlag)
	{
		//waitIndicator.activityLabel.text = @"";
		//[self.view addSubview: waitIndicator];
		//[waitIndicator animateShow];
        
        [self.view addSubview: hud];
        [hud show:YES];
	}
	else
	{
		//if (waitIndicator.superview) [waitIndicator removeFromSuperview];
        if (hud.superview) [hud removeFromSuperview];
	}
    
    [self.tabBarController.tabBar setUserInteractionEnabled:!aFlag];
    [self.navigationController.navigationBar setUserInteractionEnabled:!aFlag];    
}

- (void) setWaitTitle:(NSString *) newTitle
{
	//waitIndicator.activityLabel.text = newTitle;
    hud.labelText = newTitle;
}

#pragma mark - Setup

- (void) setupNavBar
{
    //navbar title
    UILabel *titleView = (UILabel *)self.navigationItem.titleView;
    if (!titleView) 
    {
        self.navigationItem.titleView = [APP_CONTEXT navBarLabel];
    }
}


#pragma mark - Notifications

- (void) accountsListUpdated:(NSNotification *)notification
{
    
}

- (void) balanceCheckStarted:(NSNotification *)notification
{
    //queue started
}

- (void) balanceCheckProgress:(NSNotification *)notification
{
    //queue request started
}

- (void) balanceChecked:(NSNotification *)notification
{
    //queue request processed
}

- (void) balanceCheckStopped:(NSNotification *)notification
{
    //queue stopped
}


@end
