//
//  KSNetworkActivityIndicatorManager.h
//
//  Created by Kai Straßmann on 15.10.13.
//

#import <Foundation/Foundation.h>

@interface KSNetworkActivityIndicatorManager : NSObject
+ (KSNetworkActivityIndicatorManager*) sharedManager;
- (void)increase; // call when a new network activity starts
- (void)decrease; // call when a network activity finishes
@end
