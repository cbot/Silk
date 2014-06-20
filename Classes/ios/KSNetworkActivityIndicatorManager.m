//
//  KSNetworkActivityIndicatorManager.m
//
//  Created by Kai Straßmann on 15.10.13.
//

#import "KSNetworkActivityIndicatorManager.h"

static	KSNetworkActivityIndicatorManager *_indicatorManager = nil;

@interface KSNetworkActivityIndicatorManager ()
@property (atomic, assign) int numberOfActivities;
@end

@implementation KSNetworkActivityIndicatorManager
+ (KSNetworkActivityIndicatorManager*) sharedManager {
	static dispatch_once_t onceToken;
	
	dispatch_once(&onceToken, ^{
		_indicatorManager = [[KSNetworkActivityIndicatorManager alloc] init];
	});
	return _indicatorManager;
}

- (void)increase {
	@synchronized (self) {
		self.numberOfActivities++;
		[self showOrHide];
	}
}

- (void)decrease {
	@synchronized (self) {
		self.numberOfActivities--;
		[self showOrHide];
	}
}

- (void)showOrHide {
	if (self.numberOfActivities > 0) {
		[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
	} else {
		[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
	}
	if (self.numberOfActivities < 0) NSLog(@"numberOfActivities < 0!");
}
@end
