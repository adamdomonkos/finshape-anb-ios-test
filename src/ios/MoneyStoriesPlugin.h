//
//  MoneyStoriesPlugin.h
//  MoneyStoriesTestApp
//
//  Created by Martin Prusa on 21.08.2023.
//

#import <Foundation/Foundation.h>
#import <Cordova/CDV.h>

NS_ASSUME_NONNULL_BEGIN

@import MoneyStories;

@interface MoneyStoriesPlugin : CDVPlugin

- (void)initializeSdk:(CDVInvokedUrlCommand *)command;

- (void)openStories:(CDVInvokedUrlCommand *)command;

- (void)refreshToken:(CDVInvokedUrlCommand *)command;

@end

NS_ASSUME_NONNULL_END
