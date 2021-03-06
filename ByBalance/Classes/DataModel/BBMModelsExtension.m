//
//  BBMModelsExtension.m
//  ByBalance
//
//  Created by Andrew Sinkevitch on 01.05.13.
//  Copyright (c) 2013 sinkevitch.name. All rights reserved.
//

#import "BBMModelsExtension.h"

@implementation BBMAccount (ByBalance)

- (NSString *) nameLabel
{
    if ([self.label length] > 0) return [NSString stringWithString:self.label];
    return [NSString stringWithString:self.username];
}

- (BBMBalanceHistory *) lastBalance
{
    if (!self.history) return nil;
    
    NSPredicate * predicate = [NSPredicate predicateWithFormat:@"account=%@", self];
    return [BBMBalanceHistory findFirstWithPredicate:predicate
                                            sortedBy:@"date"
                                           ascending:NO];
}

- (BBMBalanceHistory *) lastGoodBalance
{
    if (!self.history) return nil;
    
    NSPredicate * predicate = [NSPredicate predicateWithFormat:@"extracted=1 AND account=%@", self];
    return [BBMBalanceHistory findFirstWithPredicate:predicate
                                            sortedBy:@"date"
                                           ascending:NO];
}

- (NSString *) lastGoodBalanceDate
{
    BBMBalanceHistory * bh = [self lastGoodBalance];
    if (!bh) return @"";
    
    return [DATE_HELPER formatSmartAsDayOrTime:bh.date];
}

- (NSString *) lastGoodBalanceValue
{
    BBMBalanceHistory * bh = [self lastGoodBalance];
    if (!bh) return @"не обновлялся";
    
    return [NSNumberFormatter localizedStringFromNumber:bh.balance numberStyle:NSNumberFormatterDecimalStyle];
}

+ (NSNumber *) nextOrder
{
    NSInteger next = 1;
    BBMAccount * last = [BBMAccount findFirstWithPredicate:nil sortedBy:@"order" ascending:NO];
    if (last)
    {
        next = [last.order integerValue] + 1;
    }
    
    return [NSNumber numberWithInteger:next];
}

- (BOOL) balanceLimitCrossed
{
    double balanceLimit = [self.balanceLimit doubleValue];
    if (balanceLimit <= 0) return NO;
    
    BBMBalanceHistory * h = [self lastGoodBalance];
    if (!h) return NO;
    
    double balance = [h.balance doubleValue];
    return (balanceLimit > balance);
}

@end
