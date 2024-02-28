//
//  MoneyStoriesPlugin.m
//  MoneyStoriesTestApp
//
//  Created by Martin Prusa on 21.08.2023.
//

#import "MoneyStoriesPlugin.h"

@interface MoneyStoriesPlugin ()

@property(nonatomic, strong) NSString *baseURL;
@property(nonatomic, strong) NSString *accessToken;
@property(nonatomic, strong) NSString *languageCode;
@property(nonatomic, strong) NSString *customerId;

@property(nonatomic, strong) MoneyStoriesObjcInjector *objcInjector;
@property(nonatomic, strong) StoryBarViewModelObjcInjector *viewModelObjcInjector;

@property(nonatomic, strong) NSString *callbackId;

@end

@implementation MoneyStoriesPlugin

- (void)initializeSdk:(CDVInvokedUrlCommand *)command {
    NSDictionary *params = (NSDictionary *) command.arguments.firstObject;
    if (params == nil) {
        [self sendPluginResult:command status:CDVCommandStatus_ERROR message:@"Error: Missing input parameters"];
        return;
    }

    [self setupArgumentsToInitSDK:command dict:params];
    self.objcInjector = [[MoneyStoriesObjcInjector alloc] init];
    self.viewModelObjcInjector = [[StoryBarViewModelObjcInjector alloc] init];
    [self.viewModelObjcInjector.injectedStoryBarViewModel setUpdateCompletion:^{
        [self updateWith:self.viewModelObjcInjector.injectedStoryBarViewModel.storyLines];
    }];

    ConfigBuilder *builder = [[[[[ConfigBuilder alloc] init] withDebugEnabled] withBaseUrl:[NSURL URLWithString:self.baseURL]] withLanguageCode:self.languageCode];
    [self.objcInjector.injectedMoneyStories setupWithConfigBuilder:builder];

    NSError *error;
    BearerToken *token = [[BearerToken alloc] initWithToken:self.accessToken error:&error];
    [self.objcInjector.injectedMoneyStories authenticateWithCredential:token];

    self.callbackId = command.callbackId;
    [self initStoryBarViewModel];

    if (error != nil) {
        [self sendPluginResult:command status:CDVCommandStatus_ERROR message:@"Error: Missing input parameters"];
    }
}

- (void)openStories:(CDVInvokedUrlCommand *)command {
    NSDictionary *params = (NSDictionary *) command.arguments.firstObject;

    if (![params[@"period"] isKindOfClass:[NSString class]] || ![params[@"date"] isKindOfClass:[NSString class]]) {
        [self sendPluginResult:command status:CDVCommandStatus_ERROR message:@"Error: Missing input parameters"];
        return;
    }

    NSString *period;
    if ([params[@"period"] isKindOfClass:[NSString class]]) {
        period = params[@"period"];
    }

    NSString *date;
    if ([params[@"date"] isKindOfClass:[NSString class]]) {
        date = params[@"date"];
    }

    if ([period isEqualToString:@"MORE"]) {
        [self.viewModelObjcInjector.injectedStoryBarViewModel openMore];
    } else {
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.dateFormat = @"yyyy-MM-dd";

        for (MoneyStoriesStoryLine *storyLine in self.viewModelObjcInjector.injectedStoryBarViewModel.storyLines) {
            if ([date isEqualToString:[dateFormatter stringFromDate:storyLine.getStartDate]] && [period isEqualToString:storyLine.getPeriodString]) {
                [self.viewModelObjcInjector.injectedStoryBarViewModel openStoryLine:[self.viewModelObjcInjector.injectedStoryBarViewModel.storyLines indexOfObject:storyLine]];
                break;
            }
        }
    }
}

- (void)refreshToken:(CDVInvokedUrlCommand *)command {
    NSString *token = (NSString *) command.arguments.firstObject;

    if (token == nil) {
        [self sendPluginResult:command status:CDVCommandStatus_ERROR message:@"Error: Missing input parameters"];
        return;
    }

    NSError *error;
    BearerToken *bearerToken = [[BearerToken alloc] initWithToken:token error:&error];
    [self.objcInjector.injectedMoneyStories authenticateWithCredential:bearerToken];

    if (error != nil) {
        [self sendPluginResult:command status:CDVCommandStatus_ERROR message:@"Error: Missing input parameters"];
    }
}

- (void)setupArgumentsToInitSDK:(CDVInvokedUrlCommand *)command dict:(NSDictionary *)dict {
    if ([dict[@"baseUrl"] isKindOfClass:[NSString class]]) {
        NSString *baseURLString = dict[@"baseUrl"];
        if ([[baseURLString substringFromIndex:[baseURLString length] - 1] isEqualToString:@"/"]) {
            baseURLString = [baseURLString substringToIndex:[baseURLString length] - 1];
        }

        self.baseURL = baseURLString;
        NSLog(@"baseURL is: %@", dict[@"baseUrl"]);
    } else {
        NSLog(@"baseURL is: null");
        [self sendPluginResult:command status:CDVCommandStatus_ERROR message:@"Error: Missing input parameters"];
    }

    if ([dict[@"languageCode"] isKindOfClass:[NSString class]]) {
        self.languageCode = dict[@"languageCode"];
        NSLog(@"languageCode is: %@", dict[@"languageCode"]);
    } else {
        NSLog(@"languageCode is: null");
        [self sendPluginResult:command status:CDVCommandStatus_ERROR message:@"Error: Missing input parameters"];
    }

    if ([dict[@"accessToken"] isKindOfClass:[NSString class]]) {
        self.accessToken = dict[@"accessToken"];
        NSLog(@"accessToken is: %@", dict[@"accessToken"]);
    } else {
        NSLog(@"accessToken is: null");
        [self sendPluginResult:command status:CDVCommandStatus_ERROR message:@"Error: Missing input parameters"];
    }

    if ([dict[@"customerId"] isKindOfClass:[NSString class]]) {
        NSLog(@"customerId is: %@", dict[@"customerId"]);
        self.customerId = dict[@"customerId"];
    } else {
        NSLog(@"customerId is: null");
        [self sendPluginResult:command status:CDVCommandStatus_ERROR message:@"Error: Missing input parameters"];
    }
}

- (void)sendPluginResult:(CDVInvokedUrlCommand *)command status:(CDVCommandStatus)status message:(NSString *)message {
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:status messageAsString:message];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void)initStoryBarViewModel {
    [self.viewModelObjcInjector.injectedStoryBarViewModel initializeWithCompletion:^(BOOL success, NSError * _Nullable error) {
        if (success && error == nil) {
            [self getStoryLines];
        }
    }];
}

- (void)getStoryLines {
    [self.viewModelObjcInjector.injectedStoryBarViewModel getStoryLinesWithCompletion:^(NSArray<MoneyStoriesStoryLine *> * _Nullable storyLines, NSError * _Nullable error) {
        if (storyLines && error == nil) {
            [self updateWith:storyLines];
        } else {
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Error to retrieve the stories"];
            [self.commandDelegate sendPluginResult:result callbackId:self.callbackId];
        }
    }];
}

- (void)updateWith:(NSArray<MoneyStoriesStoryLine *> * _Nonnull)storyLines {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy-MM-dd";

    NSMutableArray *storiesArray = @[].mutableCopy;
    for (MoneyStoriesStoryLine *storyLine in storyLines) {
        [storiesArray addObject:@{
            @"startDate": [dateFormatter stringFromDate:storyLine.getStartDate],
            @"read": @(storyLine.isRead),
            @"period": storyLine.getPeriodString
        }];
    }

    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:storiesArray options:NSJSONWritingPrettyPrinted error:&error];
    if (error != nil) {
        NSLog(@"NSJSONSerialization error: %@", [error localizedDescription]);
    }

    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    jsonString = [jsonString stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    jsonString = [jsonString stringByReplacingOccurrencesOfString:@" " withString:@""];
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:jsonString];

    [self.commandDelegate sendPluginResult:result callbackId:self.callbackId];
}

@end
