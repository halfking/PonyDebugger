//
//  PDASLConsoleDomainController.m
//  PonyDebugger
//
//  Created by Steve White on 9/9/12.
//
//

#import "PDASLConsoleDomainController.h"
#include <asl.h>

@interface PDASLConsoleDomainController () {
  NSTimer *_pollTimer;
  time_t _lastPollTime;
  aslclient _client;
  NSDateFormatter *_dateFormatter;
}

@end

@implementation PDASLConsoleDomainController

@dynamic domain;

#pragma mark - Statics

+ (PDASLConsoleDomainController *)defaultInstance;
{
  static PDASLConsoleDomainController *defaultInstance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    defaultInstance = [[PDASLConsoleDomainController alloc] init];
  });
  
  return defaultInstance;
}

+ (Class)domainClass;
{
  return [PDConsoleDomain class];
}

#pragma mark - Initialization
- (id) init {
  self = [super init];
  if (self != nil) {
    _client = asl_open("PDASLConsoleDomainController",
                       [[[[NSBundle mainBundle] infoDictionary] objectForKey:(__bridge NSString *)kCFBundleIdentifierKey] UTF8String],
                       0U);
    _dateFormatter = [[NSDateFormatter alloc] init];
    _dateFormatter.dateFormat = @"%Y.%m.%d %H:%M:%S %Z";
  }
  return self;
}

- (void) dealloc {
  if (_pollTimer != nil) {
    [_pollTimer invalidate];
    _pollTimer = nil;
  }
  if (_client != NULL) {
    asl_close(_client);
    _client = NULL;
  }
}

- (void)pollASL:(NSTimer *)timer {
	aslmsg query = asl_new(ASL_TYPE_QUERY);
  
	time_t now = time(NULL);
  
	//Get all messages since the last poll, but before now. We will get messages with the current time on our next poll.
	int result = asl_set_query(query, ASL_KEY_TIME, [[NSString stringWithFormat:@"%lu", _lastPollTime] UTF8String], ASL_QUERY_OP_GREATER_EQUAL | ASL_QUERY_OP_NUMERIC);
	result = asl_set_query(query, ASL_KEY_TIME, [[NSString stringWithFormat:@"%lu", now] UTF8String], ASL_QUERY_OP_LESS | ASL_QUERY_OP_NUMERIC);
	//Update the last-poll time so that we don't get the same messages over and over again.
	_lastPollTime = now;
  
	result = asl_set_query(query, ASL_KEY_LEVEL, [[NSString stringWithFormat:@"%i", 8 /*minimumLevel*/] UTF8String], ASL_QUERY_OP_LESS_EQUAL | ASL_QUERY_OP_NUMERIC);
  
	aslresponse response = asl_search(_client, query);
  
	asl_free(query);
  
	if(response) {
		//Get some search results.
    
		aslmsg msg;
		while((msg = aslresponse_next(response))) {
			NSString *msgDateString = [NSString stringWithUTF8String:asl_get(msg, ASL_KEY_TIME)];
			NSDate *msgDate;
			NSTimeInterval msgTimeUNIX;
      
			//10.4 compatibility: On Tiger, asl_search gives us messages whose ASL_KEY_TIME is set to a string representation of the date, rather than a string representation of the number of seconds since the Epoch.
			msgDate = [_dateFormatter dateFromString:msgDateString];
			if(msgDate) {
				msgTimeUNIX = [msgDate timeIntervalSince1970];
			} else {
				msgTimeUNIX = [msgDateString doubleValue];
				msgDate = [NSDate dateWithTimeIntervalSince1970:msgTimeUNIX];
			}
      
			NSString *title = [NSString stringWithFormat:@"%s", asl_get(msg, ASL_KEY_SENDER)];
			NSString *description = [NSString stringWithFormat:@"%@ %s", msgDate, asl_get(msg, ASL_KEY_MSG)];
			//Higher ASL priority numbers indicate lower priority; we need to simply flip them around.
			//DEBUG should be -2; INFO should be -1; NOTICE should be 0; etc.
			signed priority = ASL_LEVEL_NOTICE - strtol(asl_get(msg, ASL_KEY_LEVEL), /*nextp*/ NULL, /*radix*/ 10);
      
      PDConsoleConsoleMessage *message = [[PDConsoleConsoleMessage alloc] init];
      message.level = [[NSNumber numberWithInt:priority] stringValue];
      message.text = description;
      message.url = title;

      [self.domain messageAddedWithMessage:message];
		}
    
		aslresponse_free(response);
	}
}

#pragma mark - PDConsoleCommandDelegate

// Enables console domain, sends the messages collected so far to the client by means of the <code>messageAdded</code> notification.
- (void)domain:(PDConsoleDomain *)domain enableWithCallback:(void (^)(id error))callback {
  if (_pollTimer == nil) {
    _pollTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                  target:self
                                                selector:@selector(pollASL:)
                                                userInfo:nil
                                                 repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:_pollTimer forMode:NSRunLoopCommonModes];
    time(&_lastPollTime);
  }
  callback(nil);
}

// Disables console domain, prevents further console messages from being reported to the client.
- (void)domain:(PDConsoleDomain *)domain disableWithCallback:(void (^)(id error))callback {
  if (_pollTimer != nil) {
    [_pollTimer invalidate];
    _pollTimer = nil;
  }
  callback(nil);
}

// Clears console messages collected in the browser.
- (void)domain:(PDConsoleDomain *)domain clearMessagesWithCallback:(void (^)(id error))callback {
  callback(nil);
}

// Toggles monitoring of XMLHttpRequest. If <code>true</code>, console will receive messages upon each XHR issued.
// Param enabled: Monitoring enabled state.
- (void)domain:(PDConsoleDomain *)domain setMonitoringXHREnabledWithEnabled:(NSNumber *)enabled callback:(void (^)(id error))callback {
  callback(nil);
}

// Enables console to refer to the node with given id via $x (see Command Line API for more details $x functions).
// Param nodeId: DOM node id to be accessible by means of $x command line API.
- (void)domain:(PDConsoleDomain *)domain addInspectedNodeWithNodeId:(NSNumber *)nodeId callback:(void (^)(id error))callback {
  callback(nil);
}

- (void)domain:(PDConsoleDomain *)domain addInspectedHeapObjectWithHeapObjectId:(NSNumber *)heapObjectId callback:(void (^)(id error))callback {
  callback(nil);
}

@end
