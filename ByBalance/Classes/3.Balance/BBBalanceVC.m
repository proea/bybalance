//
//  BBBalanceVC.m
//  ByBalance
//
//  Created by Andrew Sinkevitch on 12/08/2012.
//  Copyright (c) 2012 sinkevitch.name. All rights reserved.
//

#import "BBBalanceVC.h"
#import "BBAccountFormVC.h"
#import "BBHistoryAllCells.h"

typedef enum
{
	kAlertModeDeleteAccount,
	kAlertModeClearHistory,
	
} kAlertMode;

static NSString * cellId1 = @"BBHistoryCommonCellID";
static NSString * cellId2 = @"BBHistoryAnitexCellID";
static NSString * cellId3 = @"BBHistoryBonusesCellID";

static NSString * nib1 = @"BBHistoryCommonCell";
static NSString * nib2 = @"BBHistoryAnitexCell";
static NSString * nib3 = @"BBHistoryBonusesCell";


@interface BBBalanceVC ()

@property (strong,nonatomic) NSArray * history;
@property (strong,nonatomic) UIView * vCircle;
@property (strong,nonatomic) UIView * ipadSplash;

- (void) onBtnEdit:(id)sender;
- (void) onBtnDelete:(id)sender;
- (void) updateScreen;
- (void) clearHistory;
- (void) updateNavBar;
- (void) makeIpadSplash;
@end

@implementation BBBalanceVC

@synthesize account;
@synthesize history;
@synthesize vCircle;

- (void) viewDidLoad
{
    [super viewDidLoad];
    
    [tblHistory setSeparatorColor:[APP_CONTEXT colorGrayMedium]];
    
    historyStay = 5;
    
    [self updateScreen];
    
    [APP_CONTEXT makeRedButton:btnRefresh];
    [APP_CONTEXT makeRedButton:btnClear];
    btnClear.alpha = 0.7f;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(accountsListUpdated:) name:kNotificationOnAccountsListUpdated object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(balanceChecked:) name:kNotificationOnBalanceChecked object:nil];
    
    [self makeIpadSplash];
}


- (void) cleanup
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kNotificationOnAccountsListUpdated object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kNotificationOnBalanceChecked object:nil];
    
    self.account = nil;
    self.history = nil;
    
    [super cleanup];
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (needUpdateScreen)
    {
        [self updateScreen];
        
        needUpdateScreen = NO;
    }
    
    id<GAITracker> tracker = [[GAI sharedInstance] defaultTracker];
    [tracker set:kGAIScreenName value:@"Баланс"];
    [tracker send:[[GAIDictionaryBuilder createScreenView]  build]];
}

#pragma mark - Logic

- (void)setAccount:(BBMAccount *)newAcc
{
    account = newAcc;
    
    if (APP_CONTEXT.masterPC != nil) [APP_CONTEXT.masterPC dismissPopoverAnimated:YES];
    
    [self updateScreen];
}

#pragma mark - Setup

- (void) setupNavBar
{
    [super setupNavBar];
    
    if (APP_CONTEXT.isIphone)
    {
        //left button
        UIBarButtonItem * btnInfo = [APP_CONTEXT buttonFromName:@"arrow_left"];
        [(UIButton *)btnInfo.customView addTarget:self action:@selector(onNavButtonLeft:) forControlEvents:UIControlEventTouchUpInside];
        self.navigationItem.leftBarButtonItem = btnInfo;
        
    }
    
    //title
    UILabel *titleView = (UILabel *)self.navigationItem.titleView;
    titleView.text = @"Баланс";
    [titleView sizeToFit];
    
    //right button
    UIBarButtonItem * btnEdit = [APP_CONTEXT buttonFromName:@"edit"];
    [(UIButton *)btnEdit.customView addTarget:self action:@selector(onBtnEdit:) forControlEvents:UIControlEventTouchUpInside];
    
    UIBarButtonItem * btnDelete = [APP_CONTEXT buttonFromName:@"delete"];
    [(UIButton *)btnDelete.customView addTarget:self action:@selector(onBtnDelete:) forControlEvents:UIControlEventTouchUpInside];
    
    self.navigationItem.rightBarButtonItems = [NSArray arrayWithObjects:btnDelete, btnEdit, nil];
    
}

- (void) updateNavBar
{
    if (APP_CONTEXT.isIphone) return;
    
    if (self.account == nil)
    {
        self.navigationItem.rightBarButtonItems = nil;
    }
    else
    {
        //right button
        UIBarButtonItem * btnEdit = [APP_CONTEXT buttonFromName:@"edit"];
        [(UIButton *)btnEdit.customView addTarget:self action:@selector(onBtnEdit:) forControlEvents:UIControlEventTouchUpInside];
        
        UIBarButtonItem * btnDelete = [APP_CONTEXT buttonFromName:@"delete"];
        [(UIButton *)btnDelete.customView addTarget:self action:@selector(onBtnDelete:) forControlEvents:UIControlEventTouchUpInside];
        
        self.navigationItem.rightBarButtonItems = [NSArray arrayWithObjects:btnDelete, btnEdit, nil];
    }
    
}


#pragma mark - Actions

- (IBAction) onNavButtonLeft:(id)sender
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void) onBtnEdit:(id)sender
{
    BBAccountFormVC * vc = NEWVCFROMNIB(BBAccountFormVC);
    vc.account = self.account;
    vc.editMode = YES;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void) onBtnDelete:(id)sender
{
    
    alertMode = kAlertModeDeleteAccount;
    
    [APP_CONTEXT showAlertWithTitle:@"" 
                            andText:@"Удалить этот аккаунт?" 
                        andDelegate:self 
                   andButtonsTitles:[NSArray arrayWithObjects:@"Нет", @"Да", nil]];
}

- (IBAction) onBtnRefresh:(id)sender
{
    if (![APP_CONTEXT isOnline])
    {
        [APP_CONTEXT showAlertForNoInternet];
        return;
    }
    
    if ([BALANCE_CHECKER isBusy])
    {
        [APP_CONTEXT showToastWithText:@"Идёт обновление, подождите"];
        return;
    }
    
    //add one account
    [BALANCE_CHECKER addItem:account];
}

- (IBAction) onBtnClear:(id)sender
{
    if (!history) return;
    
    NSInteger total = [history count];
    
    if (total <= historyStay) return;
    
    alertMode = kAlertModeClearHistory;
    
    NSString * msg = [NSString stringWithFormat:@"Будут оставлены последние %ld записей. Очистить историю?", (long)historyStay];
    
    [APP_CONTEXT showAlertWithTitle:@"" 
                            andText:msg 
                        andDelegate:self
                   andButtonsTitles:[NSArray arrayWithObjects:@"Нет", @"Да", nil]];
}


#pragma mark - Notifications

- (void) accountsListUpdated:(NSNotification *)notification
{
    needUpdateScreen = YES;
}

- (void) balanceChecked:(NSNotification *)notification
{
    DDLogVerbose(@"BBBalanceVC.balanceChecked");
    
    BBMAccount * updatedAcc = [[notification userInfo] objectForKey:kDictKeyAccount];
    if (!updatedAcc) return;
    
    if ([updatedAcc.type.id integerValue] == [self.account.type.id integerValue] &&
        updatedAcc.username == self.account.username)
    {
        DDLogVerbose(@"account matches");
        [self updateScreen];
    }
}

#pragma mark - Private

- (void) updateScreen
{
    [self updateNavBar];
    
    if (self.account == nil)
    {
        self.ipadSplash.hidden = NO;
    }
    else {
        self.ipadSplash.hidden = YES;
    }
    
    lblType.text = account.type.name;
    lblName.text = account.username;
    lblLabel.text = account.label;
    
    lblDate.text = [account lastGoodBalanceDate];
    lblBalance.text = [account lastGoodBalanceValue];
    
    NSPredicate * predicate = [NSPredicate predicateWithFormat:@"account=%@", self.account];
    self.history = [BBMBalanceHistory findAllSortedBy:@"date"
                                            ascending:NO
                                        withPredicate:predicate];
    
    if ([history count] < 1)
    {
        //no history
        tblHistory.hidden = YES;
        btnClear.hidden = YES;
        lblHistory.hidden = YES;
    }
    else
    {
        //update table
        tblHistory.hidden = NO;
        [tblHistory reloadData];
        lblHistory.hidden = NO;
        btnClear.hidden = ([history count] <= historyStay);
    }
    
    
    if ([account balanceLimitCrossed])
    {
        if (!self.vCircle)
        {
            self.vCircle = [APP_CONTEXT circleWithColor:[APP_CONTEXT colorRed] radius:5];
            [self.view addSubview:vCircle];
        }
        
        CGFloat textWidth = [APP_CONTEXT labelTextWidth:lblBalance];
        CGFloat circleX = lblBalance.frame.origin.x + lblBalance.frame.size.width - textWidth - vCircle.frame.size.width - 3;
        CGFloat circleY = lblBalance.frame.origin.y + (lblBalance.frame.size.height - vCircle.frame.size.height)/2;
        vCircle.frame = CGRectMake(circleX, circleY, vCircle.frame.size.width, vCircle.frame.size.height);
    }
    else
    {
        [self.vCircle removeFromSuperview];
        self.vCircle = nil;
    }
    
    if (APP_CONTEXT.isIpad)
    {
        //update title
        UILabel *titleView = (UILabel *)self.navigationItem.titleView;
        titleView.text = account.type.name;
        [titleView sizeToFit];
    }
}

- (void) clearHistory
{
    NSInteger c = 0;
    NSInteger total = [history count];
    
    if (total <= historyStay) return;
    
    for (BBMBalanceHistory * bh in history)
    {
        c++;
        if (c > historyStay)
        {
            [bh deleteEntity];
        }
    }
    
    [APP_CONTEXT saveDatabase];
    
    [self updateScreen];
}

- (void) makeIpadSplash
{
    if (!APP_CONTEXT.isIpad) return;
    
    UIView * splash = [[UIView alloc] initWithFrame:CGRectZero];
    splash.translatesAutoresizingMaskIntoConstraints = NO;
    splash.backgroundColor = [APP_CONTEXT colorBg];
    [self.view addSubview:splash];
    
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:splash
                                                          attribute:NSLayoutAttributeTop
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.view
                                                          attribute:NSLayoutAttributeTop
                                                         multiplier:1.0
                                                           constant:0.0]];
    
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:splash
                                                          attribute:NSLayoutAttributeLeading
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.view
                                                          attribute:NSLayoutAttributeLeading
                                                         multiplier:1.0
                                                           constant:0.0]];
    
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:splash
                                                          attribute:NSLayoutAttributeBottom
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.view
                                                          attribute:NSLayoutAttributeBottom
                                                         multiplier:1.0
                                                           constant:0.0]];
    
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:splash
                                                          attribute:NSLayoutAttributeTrailing
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.view
                                                          attribute:NSLayoutAttributeTrailing
                                                         multiplier:1.0
                                                           constant:0.0]];
    
    self.ipadSplash = splash;
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    
    if (alertMode == kAlertModeDeleteAccount)
    {    
        if (buttonIndex == 1)
        {
            id<GAITracker> tracker = [[GAI sharedInstance] defaultTracker];
            [tracker send:[[GAIDictionaryBuilder createEventWithCategory:@"account"
                                                                  action:@"account_delete"
                                                                   label:[NSString stringWithFormat:@"%@", account.type.name]
                                                                   value:nil] build]];
            
            [account deleteEntity];
            [APP_CONTEXT saveDatabase];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationOnAccountDeleted object:nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationOnAccountsListUpdated object:nil];
            
            
            if (APP_CONTEXT.isIphone)
            {
                [self.navigationController popToRootViewControllerAnimated:YES];
            }
            else
            {
                self.account = nil;
            }
            
            [APP_CONTEXT showToastWithText:@"Аккаунт удалён"]; 
        }
    }
    
    if (alertMode == kAlertModeClearHistory)
    {    
        if (buttonIndex == 1)
        {
            [self clearHistory];
            
            NSString * msg = [NSString stringWithFormat:@"История очищена. Оставлены последние %ld записей.", (long)historyStay];
            [APP_CONTEXT showToastWithText:msg]; 
        }
    }
}



#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)_tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.history count];
}

- (UITableViewCell *)tableView:(UITableView *)_tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSArray * nibs;
    NSString * cellId = nil;
    NSString * nib = nil;
    
    BBMBalanceHistory * bh = [self.history objectAtIndex:indexPath.row];
    
    if ([self.account.type.id integerValue] == kAccountAnitex)
    {
        cellId = cellId2;
        nib = nib2;
    }
    else
    {
        if ([bh.bonuses length] > 0)
        {
            DDLogVerbose(@"cellForRowAtIndexPath bonusesCell");
            cellId = cellId3;
            nib = nib3;
        }
        else
        {
            cellId = cellId1;
            nib = nib1;
        }
    }
    
    
    BBHistoryBaseCell * cell = (BBHistoryBaseCell*)[tblHistory dequeueReusableCellWithIdentifier:cellId];
    if (!cell)
    {
        nibs = [[NSBundle mainBundle] loadNibNamed:nib owner:self options:nil];
        cell = [nibs objectAtIndex:0];
        cell.backgroundColor = [UIColor clearColor]; //universal app, ipad makes bg white
    }
    
    
    [cell setupWithHistory:bh];
    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)_tableView
{
    return 1;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)_tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    //return [self.account.type.id integerValue] == kAccountAnitex ? kHistoryCellHeight2 : kHistoryCellHeight1;
    if ([self.account.type.id integerValue] == kAccountAnitex)
    {
        return kHistoryCellHeight2;
    }
    else
    {
        BBMBalanceHistory * bh = [self.history objectAtIndex:indexPath.row];
        
        if ([bh.bonuses length] > 0)
        {
            
            static BBHistoryBonusesCell * cell = nil;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                cell = [tblHistory dequeueReusableCellWithIdentifier:cellId3];
            });
            /*
            cell.bounds = CGRectMake(0.0f, 0.0f, CGRectGetWidth(tblHistory.bounds), 0.0f);
            [cell setNeedsLayout];
            [cell layoutIfNeeded];
            [cell updateConstraintsIfNeeded];
            
            DDLogVerbose(@"width: %f", cell.contentView.frame.size.width);
            
            NSString *label =  bh.bonuses;
            CGSize stringSize = [label sizeWithFont:[UIFont boldSystemFontOfSize:15]
                                  constrainedToSize:CGSizeMake(cell.contentView.frame.size.width, 9999)
                                      lineBreakMode:UILineBreakModeWordWrap];
            
            return kHistoryCellHeight3 + stringSize.height - 18;
            */
            
            //[cell setupWithHistory:bh];
            //return [self calculateHeightForBonusesCell:cell];
            
            return kHistoryCellHeight3;
        }
        else
        {
            return kHistoryCellHeight1;
        }
    }
}

- (CGFloat)calculateHeightForBonusesCell:(BBHistoryBonusesCell *)bonusesCell
{
    /*
    NSString *label =  bh.bonuses;
    CGSize stringSize = [label sizeWithFont:[UIFont boldSystemFontOfSize:15]
                          constrainedToSize:CGSizeMake(320, 9999)
                              lineBreakMode:UILineBreakModeWordWrap];
    
    return kHistoryCellHeight3 + stringSize.height - 18;
    */
    
    bonusesCell.bounds = CGRectMake(0.0f, 0.0f, CGRectGetWidth(tblHistory.bounds), 0.0f);
    
    DDLogVerbose(@"tblHistory width: %f", CGRectGetWidth(tblHistory.bounds));
    DDLogVerbose(@"bonusesCell width: %f", bonusesCell.frame.size.width);
    
    [bonusesCell setNeedsLayout];
    [bonusesCell layoutIfNeeded];
    
    CGSize size = [bonusesCell.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
    return size.height;
    
    return 0;
}

- (void)tableView:(UITableView *)_tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    //
}

#pragma mark - UISplitViewControllerDelegate

- (void)splitViewController:(UISplitViewController *)splitController willHideViewController:(UIViewController *)viewController withBarButtonItem:(UIBarButtonItem *)barButtonItem forPopoverController:(UIPopoverController *)popoverController
{
    barButtonItem.title = @"Список";
    barButtonItem.tintColor = [APP_CONTEXT colorRed];
    [self.navigationItem setLeftBarButtonItem:barButtonItem animated:YES];
    APP_CONTEXT.masterPC = popoverController;
}

- (void)splitViewController:(UISplitViewController *)splitController willShowViewController:(UIViewController *)viewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    // Called when the view is shown again in the split view, invalidating the button and popover controller.
    [self.navigationItem setLeftBarButtonItem:nil animated:YES];
    APP_CONTEXT.masterPC = nil;
}

- (BOOL)splitViewController:(UISplitViewController *)svc shouldHideViewController:(UIViewController *)vc inOrientation:(UIInterfaceOrientation)orientation
{
    return NO;
}


@end
