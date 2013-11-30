//
//  AppGlobal.h
//  ByBalance
//
//  Created by Andrew Sinkevitch on 15.06.12.
//  Copyright (c) 2012 sinkevitch.name. All rights reserved.
//

#pragma mark - APN server
//
extern NSString * const kApnServerUrl;
extern NSString * const kApnServerEnv;

#pragma mark - Text and Messages
//
extern NSString * const kAppNoInternetAlertTitle;
extern NSString * const kAppNoInternetAlertText;
//
extern NSString * const kAppEmailRegexp;

#pragma mark - Account types
//
typedef enum
{
	kAccountMts = 1,
	kAccountBn,
	kAccountVelcom,
    kAccountLife,
    kAccountTcm,
    kAccountNiks,
    kAccountDamavik,
    kAccountSolo,
    kAccountTeleset,
    kAccountByFly,
    kAccountNetBerry,
    kAccountCosmosTv,
    kAccountAtlantTelecom,
    kAccountInfolan,
    kAccountUnetBy,
    kAccountDiallog,
    kAccountAnitex,
	//----------------------
	kAccountsCount
	
} kAccounts;


#pragma mark - Periodic checks
//
typedef enum
{
	kPeriodicCheckManual = 0,
	kPeriodicCheckOnStart,
	kPeriodicCheck1,
    kPeriodicCheck2,
	//----------------------
	kPeriodicChecksCount
	
} kPeriodicChecks;


#pragma mark - Dictionary keys
//
extern NSString * const kDictKeyAccount;
extern NSString * const kDictKeyBaseItem;
extern NSString * const kDictKeyLoaderInfo;
extern NSString * const kDictKeyHtml;

#pragma mark - Notifications
//
extern NSString * const kNotificationOnAccountsListUpdated;
extern NSString * const kNotificationOnBalanceCheckStart;
extern NSString * const kNotificationOnBalanceCheckProgress;
extern NSString * const kNotificationOnBalanceChecked;
extern NSString * const kNotificationOnBalanceCheckStop;

#pragma mark - Cells sizes
//
extern const CGFloat kHomeCellHeight;
extern const CGFloat kAccountTypeCellHeight;
extern const CGFloat kHistoryCellHeight1;
extern const CGFloat kHistoryCellHeight2;
extern const CGFloat kAboutCellHeight;
//

#pragma mark - Time limits
//
extern const CGFloat kBgrTimelimit; //background fetch request limit to establish internet connection
extern const CGFloat kBgBcTimelimit; //background balance checker limit to get balances
//