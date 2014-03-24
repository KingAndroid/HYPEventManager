//
//  HYPEventManager.m
//  DansaniPlus
//
//  Created by Elvis Nunez on 24/10/13.
//  Copyright (c) 2013 Hyper. All rights reserved.
//

#import "HYPEventManager.h"
#import <EventKit/EventKit.h>

@interface HYPEventManager ()
@property (nonatomic) BOOL hasAccessToEventsStore;
@property (nonatomic, strong) EKEventStore *eventStore;
@end

@implementation HYPEventManager

+ (instancetype)sharedManager
{
    static HYPEventManager *__sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __sharedInstance = [[HYPEventManager alloc] init];
    });

    return __sharedInstance;
}

- (EKEventStore *)eventStore
{
    if (!_eventStore) {
        _eventStore = [[EKEventStore alloc] init];
    }
    return _eventStore;
}

- (void)deleteEventWithIdentifier:(NSString *)identifier completion:(void (^)(NSError *error))completion
{
    [self requestAccessToEventStoreWithCompletion:^(BOOL success, NSError *anError) {
        if (success) {
            EKEvent *event = [self.eventStore eventWithIdentifier:identifier];
            NSError *eventError = nil;
            [self.eventStore removeEvent:event span:EKSpanThisEvent error:&eventError];
            if (completion) {
                completion(eventError);
            }
        } else {
            if (completion) {
                completion(anError);
            }
        }
    }];
}

- (void)isEventInCalendar:(NSString *)eventIdentifier completion:(void (^)(BOOL found))completion
{
    [[HYPEventManager sharedManager] requestAccessToEventStoreWithCompletion:^(BOOL success, NSError *error) {
        EKEvent *event = [self.eventStore eventWithIdentifier:eventIdentifier];
        if (completion) {
            if (event) {
                completion(YES);
            } else {
                completion(NO);
            }
        }
    }];
}

- (void)updateEvent:(NSString *)eventIdentifier withTitle:(NSString *)title startDate:(NSDate *)startDate endDate:(NSDate *)endDate completion:(void (^)(NSString *eventIdentifier, NSError *error))completion
{
    [self requestAccessToEventStoreWithCompletion:^(BOOL success, NSError *anError) {
        if (success) {
            EKEvent *event = [self.eventStore eventWithIdentifier:eventIdentifier];
            if (event) {
                event.title = title;
                event.startDate = startDate;
                event.endDate = endDate;
                NSError *eventError = nil;
                BOOL created = [self.eventStore saveEvent:event span:EKSpanThisEvent error:&eventError];
                if (created) {
                    if (completion) {
                        completion(event.eventIdentifier, nil);
                    }
                } else {
                    if (completion) {
                        completion(nil, eventError);
                    }
                }
            } else {
                NSDictionary *errorDictionary = @{ NSLocalizedDescriptionKey : @"Event not found in calendar" };
                NSError *eventError = [[NSError alloc] initWithDomain:NSPOSIXErrorDomain
                                                      code:0 userInfo:errorDictionary];
                if (completion) {
                    completion(nil, eventError);
                }
            }
        } else {
            if (completion) {
                completion(nil, anError);
            }
        }
    }];
}

-(NSDate *)dateToLocalTime:(NSDate *)date
{
    NSTimeZone *tz = [NSTimeZone localTimeZone];
    NSInteger seconds = [tz secondsFromGMTForDate: date];
    return [NSDate dateWithTimeInterval: seconds sinceDate: date];
}

-(NSDate *)dateToGlobalTime:(NSDate *)date
{
    NSTimeZone *tz = [NSTimeZone localTimeZone];
    NSInteger seconds = -[tz secondsFromGMTForDate: date];
    return [NSDate dateWithTimeInterval: seconds sinceDate: date];
}

- (void)createEventWithTitle:(NSString *)title startDate:(NSDate *)aStartDate duration:(NSInteger)duration completion:(void (^)(NSString *eventIdentifier, NSError *error))completion
{
    [self requestAccessToEventStoreWithCompletion:^(BOOL success, NSError *anError) {
        if (success) {
            NSDate *startDate = [self dateToGlobalTime:aStartDate];
            EKEvent *event = [EKEvent eventWithEventStore:self.eventStore];
            event.title = title;
            event.startDate = startDate;
            event.endDate = [NSDate dateWithTimeInterval:3600 * duration sinceDate:startDate];
            event.calendar = self.eventStore.defaultCalendarForNewEvents;
            event.alarms = [NSArray arrayWithObject:[EKAlarm alarmWithAbsoluteDate:event.startDate]];
            NSError *eventError = nil;
            BOOL created = [self.eventStore saveEvent:event span:EKSpanThisEvent error:&eventError];
            if (created) {
                if (completion) {
                    completion(event.eventIdentifier, nil);
                }
            } else if (eventError) {
                if (completion) {
                    completion(nil, eventError);
                }
            }

        } else {
            if (completion) {
                completion(nil, anError);
            }
        }
    }];
}

- (void)requestAccessToEventStoreWithCompletion:(void (^)(BOOL success, NSError *error))completion
{
    if (!self.hasAccessToEventsStore) {
        [self.eventStore requestAccessToEntityType:EKEntityTypeEvent completion:^(BOOL granted, NSError *error) {
            if (error) {
                NSLog(@"error adding event to calendar: %@", [error localizedDescription]);
            }

            self.hasAccessToEventsStore = granted;
            if (completion) {
                completion(granted, error);
            }
        }];
    } else {
        if (completion) {
            completion(YES, nil);
        }
    }
}

@end
