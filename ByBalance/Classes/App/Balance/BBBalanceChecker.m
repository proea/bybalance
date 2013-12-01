//
//  BBLoadManager.m
//  ByBalance
//
//  Created by Andrew Sinkevitch on 01/09/2012.
//  Copyright (c) 2012 sinkevitch.name. All rights reserved.
//

#import "BBBalanceChecker.h"

@interface BBBalanceChecker ()

- (BBLoaderBase *)loaderForAccount:(BBMAccount *) account;

- (void) startBgFetchTimer;
- (void) stopBgFetchTimer;
- (void) onBgFetchTimerTick:(NSTimer *)timer;
- (void) onBgUpdateEnd:(BOOL)updated;

- (double) timeForCheckPeriodType:(NSInteger)periodType;

@end


@implementation BBBalanceChecker

SYNTHESIZE_SINGLETON_FOR_CLASS(BBBalanceChecker, sharedBBBalanceChecker);

- (void) start
{
    queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = 1;
    
    syncFlag1 = [[NSObject alloc] init];
    syncFlag2 = [[NSObject alloc] init];
    
    bgUpdate = NO;
}

- (BOOL) isBusy
{
    return queue.operationCount > 0;
}

- (void) stop
{
    [self stopBgFetchTimer];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (queue)
    {
        [queue cancelAllOperations];
        queue = nil;
    }
    
    if (syncFlag1) syncFlag1 = nil;
    if (syncFlag2) syncFlag2 = nil;
}

- (void) addItem:(BBMAccount *) account
{
    DDLogVerbose(@"BBBalanceChecker.addItem");
    DDLogVerbose(@"adding: %@", account.username);
    
    //new way
    BBLoaderBase * loader = [self loaderForAccount:account];
    
    if (!loader)
    {
        DDLogError(@"loader not created");
        return;
    }
    
    loader.account = account;
    loader.delegate = self;
    
    //notify about start
    if (queue.operationCount < 1)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationOnBalanceCheckStart object:self userInfo:nil];
    }
    
    [queue addOperation:loader];
}

- (void) setBgCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    bgCompletionHandler = [completionHandler copy];
}

- (void) addBgItem:(BBMAccount *)account
{
    DDLogVerbose(@"BBBalanceChecker.addBgItem");
    DDLogVerbose(@"adding: %@", account.username);
    
    BBLoaderBase * loader = [self loaderForAccount:account];
    
    if (!loader)
    {
        DDLogError(@"loader not created");
        return;
    }
    
    loader.account = account;
    loader.delegate = self;
    
    //notify about start
    if (queue.operationCount < 1)
    {
        bgUpdate = YES;
        [self startBgFetchTimer];
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationOnBalanceCheckStart object:self userInfo:nil];
    }
    
    [queue addOperation:loader];
}

#pragma mark - BBLoaderDelegate

- (void) balanceLoaderDone:(NSDictionary *)info
{
    @synchronized (syncFlag1)
	{
        DDLogVerbose(@"balanceLoaderDone");
        
        BBMAccount * account = [info objectForKey:kDictKeyAccount];
        BBLoaderInfo * loaderInfo = [info objectForKey:kDictKeyLoaderInfo];
        
        if (!account || !loaderInfo) return;
        
        //save history
        BBMBalanceHistory * bh = [BBMBalanceHistory createEntity];
        bh.date = [NSDate date];
        bh.account = account;
        bh.extracted = [NSNumber numberWithBool:loaderInfo.extracted];
        bh.incorrectLogin = [NSNumber numberWithBool:loaderInfo.incorrectLogin];
        bh.balance = loaderInfo.userBalance;
        bh.packages = loaderInfo.userPackages;
        bh.megabytes = loaderInfo.userMegabytes;
        bh.days = loaderInfo.userDays;
        bh.credit = loaderInfo.userCredit;
        bh.minutes = loaderInfo.userMinutes;
        bh.sms = loaderInfo.userSms;
        
        [APP_CONTEXT saveDatabase];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationOnBalanceChecked object:self userInfo:info];
        
        if (queue.operationCount <= 1)
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationOnBalanceCheckStop object:self userInfo:nil];
            if (bgUpdate) [self onBgUpdateEnd:YES];
        }
    }
}


#pragma mark - Private

- (BBLoaderBase *)loaderForAccount:(BBMAccount *) account
{
    NSInteger type = [account.type.id integerValue];
    
    BBLoaderBase * loader = nil;
    
    switch (type)
    {
        case kAccountMts:
            loader = [BBLoaderMts new];
            break;
            
        case kAccountBn:
            loader = [BBLoaderBn new];
            break;
            
        case kAccountVelcom:
            loader = [BBLoaderVelcom new];
            break;
            
        case kAccountLife:
            loader = [BBLoaderLife new];
            break;
            
        case kAccountTcm:
            loader = [BBLoaderTcm new];
            break;
            
        case kAccountNiks:
            loader = [BBLoaderNiks new];
            break;
            
        case kAccountDamavik:
        case kAccountSolo:
        case kAccountTeleset:
            loader = [BBLoaderDamavik new];
            [(BBLoaderDamavik*)loader actAsDamavik];
            break;
            
        case kAccountAtlantTelecom:
            loader = [BBLoaderDamavik new];
            [(BBLoaderDamavik*)loader actAsAtlantTelecom];
            break;
            
        case kAccountByFly:
            loader = [BBLoaderByFly new];
            break;
            
        case kAccountNetBerry:
            loader = [BBLoaderNetBerry new];
            break;
            
        case kAccountCosmosTv:
            loader = [BBLoaderCosmosTV new];
            break;
            
        case kAccountInfolan:
            loader = [BBLoaderInfolan new];
            break;
            
        case kAccountUnetBy:
            loader = [BBLoaderUnetBy new];
            break;
            
        case kAccountDiallog:
            loader = [BBLoaderDiallog new];
            break;
            
        case kAccountAnitex:
            loader = [BBLoaderAnitex new];
            break;
    }
    
    return loader;
}

- (void) startBgFetchTimer
{
    if (timer) [self stopBgFetchTimer];
    
    timer = [NSTimer scheduledTimerWithTimeInterval: 0.05f
                                             target: self
                                           selector:@selector(onBgFetchTimerTick:)
                                           userInfo: nil
                                            repeats:YES];
    startTime = CACurrentMediaTime();
}

- (void) stopBgFetchTimer
{
    if (timer)
    {
        [timer invalidate];
        timer = nil;
    }
}

- (void) onBgFetchTimerTick:(NSTimer *)timer
{
    CFTimeInterval elapsedTime = CACurrentMediaTime() - startTime;
    
    if (elapsedTime < kBgBcTimelimit) return;
    
    DDLogVerbose(@"time passed: %f, stopping current check", elapsedTime);
    
    [self onBgUpdateEnd:NO];
}

- (void) onBgUpdateEnd:(BOOL)updated
{
    DDLogVerbose(@"BBBalanceChecker.bgUpdated: %d", updated);
    
    [self stop];
    [self start];
    
    //bgfetch was in background
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) [APP_CONTEXT stopReachability];
    
    if (bgCompletionHandler)
    {
        if (updated)
        {
            DDLogVerbose(@"bgFetch - normal update end");
            bgCompletionHandler(UIBackgroundFetchResultNewData);
        }
        else
        {
            DDLogVerbose(@"bgFetch - no enough time to complete");
            bgCompletionHandler(UIBackgroundFetchResultNewData);
        }
    }
    
    bgCompletionHandler = nil;
}

- (NSArray *) checkPeriodTypes
{
    //array indexes must match kCheckTypes enum
    
    static NSArray * checkTypes;
    
    if (!checkTypes)
    {
        if ([APP_CONTEXT isIos7])
        {
            checkTypes = [NSArray arrayWithObjects:@"Вручную", @"При запуске", @"Каждые 2 часа", @"Каждые 4 часа", @"Каждые 8 часов", @"Раз в сутки", nil];
        }
        else
        {
            checkTypes = [NSArray arrayWithObjects:@"Вручную", @"При запуске", nil];
        }
    }
    
    return checkTypes;
}

- (double) timeForCheckPeriodType:(NSInteger)periodType
{
    switch (periodType)
    {
        case kPeriodicCheckManual: return 0;
        case kPeriodicCheckOnStart: return 0;
        case kPeriodicCheck2h: return 60*60*2;
        case kPeriodicCheck4h: return 60*60*4;
        case kPeriodicCheck8h: return 60*60*8;
        case kPeriodicCheck1d: return 60*60*24;
        default: return 0;
    }
}

- (NSArray *) accountsToCheckInBg
{
    NSDate * date = [NSDate new];
    NSTimeInterval timeNow = [date timeIntervalSinceReferenceDate];
    NSTimeInterval timePassed = 0;
    
    double limit = 0;
    double timeNeverChecked = 60*60*24*365;

    BBMAccount * acc = nil;
    BBMBalanceHistory * bh = nil;
    
    //all accounts that needs to be checked
    NSMutableArray * toCheckAccounts = [[NSMutableArray alloc] initWithCapacity:20];
    
    for (acc in [BBMAccount findAllSortedBy:@"order" ascending:YES])
    {
        bh = [acc lastBalance];
        
        if (!bh) timePassed = timeNeverChecked;
        else timePassed = timeNow - [bh.date timeIntervalSinceReferenceDate];
        
        limit = [self timeForCheckPeriodType:[acc.periodicCheck integerValue]];
        
        if (limit > 0 && timePassed > limit)
        {
            [toCheckAccounts addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:acc, [NSNumber numberWithDouble:timePassed], nil]
                                                                   forKeys:[NSArray arrayWithObjects:@"account", @"timePassed", nil]]];
        }
    }
    
    NSInteger toCheckCount = [toCheckAccounts count];
    if (toCheckCount < 1) return nil;
    
    //sort by timePassed desc
    [toCheckAccounts sortUsingComparator: ^(id lhs, id rhs) {
        NSNumber * n1 = ((NSDictionary*) lhs)[@"timePassed"];
        NSNumber * n2 = ((NSDictionary*) rhs)[@"timePassed"];
        if (n1.doubleValue > n2.doubleValue) return NSOrderedAscending;
        if (n1.doubleValue < n2.doubleValue) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    
    NSInteger lim = (toCheckCount >= 4) ? 4 : toCheckCount;
    NSMutableArray * limitedList = [[NSMutableArray alloc] initWithCapacity:lim];
    for (int i=0; i<lim; i++)
    {
        NSDictionary * dic = [toCheckAccounts objectAtIndex:i];
        [limitedList addObject:[dic objectForKey:@"account"]];
    }
    
    return limitedList;
}

- (NSArray *) accountsToCheckOnStart
{
    NSDate * date = [NSDate new];
    NSTimeInterval timeNow = [date timeIntervalSinceReferenceDate];
    NSTimeInterval timePassed = 0;
    
    double limit = 60*30; //30 mins
    double timeNeverChecked = 60*60*24*365;
    
    BBMAccount * acc = nil;
    BBMBalanceHistory * bh = nil;
    
    //all accounts that needs to be checked
    NSMutableArray * toCheckAccounts = [[NSMutableArray alloc] initWithCapacity:20];
    
    for (acc in [BBMAccount findAllSortedBy:@"order" ascending:YES])
    {
        bh = [acc lastBalance];
        
        //skip others
        if ([acc.periodicCheck integerValue] != kPeriodicCheckOnStart) continue;
        
        if (!bh) timePassed = timeNeverChecked;
        else timePassed = timeNow - [bh.date timeIntervalSinceReferenceDate];
        
        if (timePassed > limit) [toCheckAccounts addObject:acc];
    }
    
    return toCheckAccounts;
}

#pragma mark - Server 

- (void) serverAddToken:(NSString *)token
{
    NSString * newToken = token;
    NSString * oldToken = [SETTINGS apnToken];
    AFHTTPClient * httpClient = [AFHTTPClient clientWithBaseURL:[NSURL URLWithString:kApnServerUrl]];
    
    if ([oldToken isEqualToString:newToken] || [oldToken length] < 1)
    {
        //add token
        NSDictionary * params = [NSDictionary dictionaryWithObjectsAndKeys:newToken, @"token", kApnServerEnv, @"env", nil];
        
        [httpClient postPath:@"add_token/" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
            
            SETTINGS.apnToken = newToken;
            [SETTINGS save];
            
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            
            DDLogError(@"%s httpclient_error: %@", __PRETTY_FUNCTION__, error.localizedDescription);
        }];
    }
    else if ([oldToken length] > 0)
    {
        //update token
        NSDictionary * params = [NSDictionary dictionaryWithObjectsAndKeys:
                                 oldToken, @"old_token",
                                 newToken, @"new_token",
                                 kApnServerEnv, @"env",
                                 nil];
        
        [httpClient postPath:@"update_token/" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
            
            SETTINGS.apnToken = newToken;
            [SETTINGS save];
            
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            
            DDLogError(@"%s httpclient_error: %@", __PRETTY_FUNCTION__, error.localizedDescription);
        }];
    }
}

- (void) serverRemoveToken
{
    NSString * token = [SETTINGS apnToken];
    
    if ([token length] < 1) return;
    
    //remove token
    
    AFHTTPClient * httpClient = [AFHTTPClient clientWithBaseURL:[NSURL URLWithString:kApnServerUrl]];
    
    NSDictionary * params = [NSDictionary dictionaryWithObjectsAndKeys:token, @"token", kApnServerEnv, @"env", nil];
    
    [httpClient postPath:@"remove_token/" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        SETTINGS.apnToken = @"";
        [SETTINGS save];
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        
        DDLogError(@"%s httpclient_error: %@", __PRETTY_FUNCTION__, error.localizedDescription);
    }];
}

@end
