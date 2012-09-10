//
//  PDFScriptRuntimeDomainController.m
//  PonyDebugger
//
//  Created by Steve White on 9/8/12.
//
//  Licensed to Square, Inc. under one or more contributor license agreements.
//  See the LICENSE file distributed with this work for the terms under
//  which Square, Inc. licenses this file to you.
//

#import "PDFScriptRuntimeDomainController.h"

#import "PDRuntimeDomainController.h"
#import "PDIndexedDBTypes.h"
#import "PDRuntimeTypes.h"

#import <FScript/FSInterpreter.h>
#import <FScript/FSVoid.h>
#import <objc/runtime.h>

const char * property_getTypeString( objc_property_t property )
{
	const char * attrs = property_getAttributes( property );
	if ( attrs == NULL )
		return ( NULL );
	
	static char buffer[256];
  int len = strlen(attrs);
	const char * e = strchr( attrs, ',' );
  if (e) {
    len = (int)(e - attrs);
  }
	memcpy( buffer, attrs, len );
	buffer[len] = '\0';
	
	return ( buffer );
}

@interface PDFScriptRuntimeDomainController () {
  FSInterpreter *_interpreter;
}


@end


@implementation PDFScriptRuntimeDomainController

@dynamic domain;

#pragma mark - Statics

+ (PDFScriptRuntimeDomainController *)defaultInstance;
{
    static PDFScriptRuntimeDomainController *defaultInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaultInstance = [[PDFScriptRuntimeDomainController alloc] init];
    });
    
    return defaultInstance;
}

+ (Class)domainClass;
{
    return [PDRuntimeDomain class];
}

#pragma mark - Initialization
- (id) init {
  self = [super init];
  if (self != nil) {
    _interpreter = [FSInterpreter interpreter];
  }
  return self;
}


- (PDRuntimeRemoteObject *) runtimeRemoteObjectForObject:(id)object
                                                  withId:(NSString *)objectId
{
  PDRuntimeRemoteObject *result = [[PDRuntimeRemoteObject alloc] init];
  if (object == nil) {
    result.type = @"undefined";
  }
  else if ([object isKindOfClass:[NSNumber class]] == YES) {
    result.type = @"number";
    result.value = object;
  }
  else if ([object isKindOfClass:[NSString class]] == YES) {
    result.type = @"string";
    result.value = object;
  }
  else if ([object isKindOfClass:[FSVoid class]] == YES) {
    result.type = @"undefined";
  }
  else {
    result.type = @"object";
    if ([object isKindOfClass:[NSArray class]] == YES || [object isKindOfClass:[NSSet class]] == YES) {
      result.subtype = @"array";
    }
    else if ([object isKindOfClass:[NSDate class]] == YES) {
      result.subtype = @"date";
    }
    
    result.classNameString = NSStringFromClass([object class]);
    result.objectDescription = [object description];
    result.objectId = objectId;
  }
  return result;
}

- (PDRuntimePropertyDescriptor *) newRuntimePropertyDescriptorForObject:(id)object
                                                                 withId:(NSString *)objectId
                                                                   name:(NSString *)name
                                                                mutable:(BOOL)mutable
{
  PDRuntimePropertyDescriptor *descriptor = [[PDRuntimePropertyDescriptor alloc] init];
  descriptor.name = name;
  descriptor.value = [self runtimeRemoteObjectForObject:object
                                                 withId:objectId];
  
  // True if the value associated with the property may be changed (data descriptors only).
  descriptor.writable = [NSNumber numberWithBool:mutable];
  // A function which serves as a getter for the property, or <code>undefined</code> if there is no getter (accessor descriptors only).
  //descriptor.get;
  // A function which serves as a setter for the property, or <code>undefined</code> if there is no setter (accessor descriptors only).
  //descriptor.set;
  // True if the type of this property descriptor may be changed and if the property may be deleted from the corresponding object.
  descriptor.configurable = [NSNumber numberWithBool:mutable];
  // True if this property shows up during enumeration of the properties on the corresponding object.
  descriptor.enumerable = [NSNumber numberWithBool:NO];
  return descriptor;
}

- (id) objectWithId:(NSString *)objectId {
  FSInterpreterResult *fscriptResult = nil;
  @try {
    fscriptResult = [_interpreter execute:objectId];
  }
  @catch (id e) {
    NSLog(@"evaluating: %@", objectId);
    NSLog(@"threw: %@", e);
  }
  if ([fscriptResult isOK]) {
    return [fscriptResult result];
  }
  return nil;
}

#pragma mark - PDRuntimeCommandDelegate

// Evaluates expression on global object.
// Param expression: Expression to evaluate.
// Param objectGroup: Symbolic group name that can be used to release multiple objects.
// Param includeCommandLineAPI: Determines whether Command Line API should be available during the evaluation.
// Param doNotPauseOnExceptionsAndMuteConsole: Specifies whether evaluation should stop on exceptions and mute console. Overrides setPauseOnException state.
// Param contextId: Specifies in which isolated context to perform evaluation. Each content script lives in an isolated context and this parameter may be used to specify one of those contexts. If the parameter is omitted or 0 the evaluation will be performed in the context of the inspected page.
// Param returnByValue: Whether the result is expected to be a JSON object that should be sent by value.
// Callback Param result: Evaluation result.
// Callback Param wasThrown: True if the result was thrown during the evaluation.
- (void)domain:(PDRuntimeDomain *)domain
evaluateWithExpression:(NSString *)expression
   objectGroup:(NSString *)objectGroup
includeCommandLineAPI:(NSNumber *)includeCommandLineAPI
doNotPauseOnExceptionsAndMuteConsole:(NSNumber *)doNotPauseOnExceptionsAndMuteConsole
     contextId:(NSNumber *)contextId
 returnByValue:(NSNumber *)returnByValue
      callback:(void (^)(PDRuntimeRemoteObject *result, NSNumber *wasThrown, id error))callback
{
  NSLog(@"%s", __PRETTY_FUNCTION__);
  if ([objectGroup isEqualToString:@"completion"] == YES) {
    callback(nil, [NSNumber numberWithBool:NO], nil);
    return;
  }
  
  NSLog(@"domain=%@", domain);
  NSLog(@"expression=%@", expression);
  NSLog(@"objectGroup=%@", objectGroup);
  NSLog(@"includeCommandLineAPI=%@", includeCommandLineAPI);
  NSLog(@"doNotPauseOnExceptionsAndMuteConsole=%@", doNotPauseOnExceptionsAndMuteConsole);
  NSLog(@"contextId=%@", contextId);
  NSLog(@"returnByValue=%@", returnByValue);
  NSLog(@"callback=%@", callback);

  PDRuntimeRemoteObject *result = nil;
  id error = nil;
  BOOL wasThrown = NO;
  //if ([objectGroup isEqualToString:@"console"] == YES) {
    FSInterpreterResult *fscriptResult = nil;
    @try {
      fscriptResult = [_interpreter execute:expression];
    }
    @catch (id e) {
      result = [self runtimeRemoteObjectForObject:e
                                           withId:nil];
      wasThrown = YES;
    }

    if (fscriptResult != nil) {
      if ([fscriptResult isOK] == NO) {
        if ([fscriptResult isExecutionError] == YES) {
          error = [fscriptResult errorMessage];
        }
        else if ([fscriptResult isSyntaxError] == YES) {
          error = [fscriptResult errorMessage];
        }
        result = [self runtimeRemoteObjectForObject:[fscriptResult errorMessage]
                                             withId:nil];
        wasThrown = YES;
      }
      else {
        id object = [fscriptResult result];
        result = [self runtimeRemoteObjectForObject:object
                                             withId:[NSString stringWithFormat:@"(%@)", expression]];
      }
    }
  //}

  callback(result, [NSNumber numberWithBool:wasThrown], error);
}

// Calls function with given declaration on the given object. Object group of the result is inherited from the target object.
// Param objectId: Identifier of the object to call function on.
// Param functionDeclaration: Declaration of the function to call.
// Param arguments: Call arguments. All call arguments must belong to the same JavaScript world as the target object.
// Param doNotPauseOnExceptionsAndMuteConsole: Specifies whether function call should stop on exceptions and mute console. Overrides setPauseOnException state.
// Param returnByValue: Whether the result is expected to be a JSON object which should be sent by value.
// Callback Param result: Call result.
// Callback Param wasThrown: True if the result was thrown during the evaluation.
- (void)domain:(PDRuntimeDomain *)domain
callFunctionOnWithObjectId:(NSString *)objectId
functionDeclaration:(NSString *)functionDeclaration
     arguments:(NSArray *)arguments
doNotPauseOnExceptionsAndMuteConsole:(NSNumber *)doNotPauseOnExceptionsAndMuteConsole
 returnByValue:(NSNumber *)returnByValue
      callback:(void (^)(PDRuntimeRemoteObject *result, NSNumber *wasThrown, id error))callback
{
  NSLog(@"%s", __PRETTY_FUNCTION__);
  NSLog(@"domain=%@", domain);
  NSLog(@"objectId=%@", objectId);
  NSLog(@"functionDeclaration=%@", functionDeclaration);
  NSLog(@"arguments=%@", arguments);
  NSLog(@"doNotPauseOnExceptionsAndMuteConsole=%@", doNotPauseOnExceptionsAndMuteConsole);
  NSLog(@"returnByValue=%@", returnByValue);
  NSLog(@"callback=%@", callback);
  
  id error = nil;
  BOOL exceptionThrown = NO;
  PDRuntimeRemoteObject *result = nil;
  if ([functionDeclaration hasPrefix:@"function setPropertyValue"] == YES) {
    if ([arguments count] == 2) {
      NSString *propertyName = [[arguments objectAtIndex:0] objectForKey:@"value"];
      id propertyValue = [[arguments objectAtIndex:1] objectForKey:@"value"];
      id object = [self objectWithId:objectId];
      id newValue = nil;
      NSString *setterObjectId = nil;
      @try {
        if ([object isKindOfClass:[NSMutableDictionary class]] == YES) {
          [object setObject:propertyValue forKey:propertyName];
          newValue = [object objectForKey:propertyName];
          setterObjectId = [NSString stringWithFormat:@"(%@ objectForKey:%@)", objectId, propertyName];
        }
        else if ([object isKindOfClass:[NSMutableArray class]] == YES) {
          [object setObject:propertyValue atIndex:[propertyName intValue]];
          newValue = [object objectAtIndex:[propertyName intValue]];
          setterObjectId = [NSString stringWithFormat:@"(%@ objectAtIndex:%@)", objectId, propertyName];
        }
        else {
          [object setValue:propertyValue forKeyPath:propertyName];
          newValue = [object valueForKeyPath:propertyName];
          setterObjectId = [NSString stringWithFormat:@"(%@ %@)", objectId, propertyName];
        }
        result = [self runtimeRemoteObjectForObject:newValue
                                             withId:setterObjectId];
      }
      @catch (id e) {
        exceptionThrown = YES;
        result = [self runtimeRemoteObjectForObject:e
                                             withId:nil];
        error = [e description];
      }
    }
  }
  callback(result, [NSNumber numberWithBool:exceptionThrown], error);
}

// Returns properties of a given object. Object group of the result is inherited from the target object.
// Param objectId: Identifier of the object to return properties for.
// Param ownProperties: If true, returns properties belonging only to the element itself, not to its prototype chain.
// Callback Param result: Object properties.
- (void)domain:(PDRuntimeDomain *)domain
getPropertiesWithObjectId:(NSString *)objectId
 ownProperties:(NSNumber *)ownProperties
      callback:(void (^)(NSArray *result, id error))callback
{
  NSLog(@"%s", __PRETTY_FUNCTION__);
  NSLog(@"domain=%@", domain);
  NSLog(@"objectId=%@", objectId);
  NSLog(@"ownProperties=%@", ownProperties);
  NSLog(@"callback=%@", callback);
  
  id object = [self objectWithId:objectId];

  NSMutableArray *results = [NSMutableArray array];

  if ([object isKindOfClass:[NSDictionary class]] == YES) {
    BOOL mutable = [object isKindOfClass:[NSMutableDictionary class]];
    for (NSString *aKey in object) {
      id aValue = [object objectForKey:aKey];
      PDRuntimePropertyDescriptor *descriptor = [self newRuntimePropertyDescriptorForObject:aValue
                                                                                     withId:[NSString stringWithFormat:@"(%@ objectForKey:%@)", objectId, aKey]
                                                                                       name:aKey
                                                                                    mutable:mutable];
      [results addObject:descriptor];

    }
  }
  else if ([object isKindOfClass:[NSArray class]] == YES) {
    BOOL mutable = [object isKindOfClass:[NSMutableArray class]];
    int arraySize = [object count];
    for (int i=0; i<arraySize; i++) {
      id aValue = [object objectAtIndex:i];
      PDRuntimePropertyDescriptor *descriptor = [self newRuntimePropertyDescriptorForObject:aValue
                                                                                     withId:[NSString stringWithFormat:@"(%@ objectAtIndex:%i)", objectId, i]
                                                                                       name:[[NSNumber numberWithInt:i] stringValue]
                                                                                    mutable:mutable];
      [results addObject:descriptor];
    }
  }
  else {
    NSArray *writablePropertyTypes = [NSArray arrayWithObjects:
                                      @"Tc", @"Td", @"Ti", @"TI", @"Tq",
                                      @"T@\"NSString\"", @"T@\"NSDate\"", @"T@\"NSNumber\"",
                                      @"T@\"NSArray\"", @"T@\"NSDictionary\"", @"T@\"NSSet\"",
                                      nil];

    Class objectClass = object_getClass(object);
    while(objectClass != NULL) {
      unsigned int i, count = 0;
      objc_property_t *classProperties = class_copyPropertyList(objectClass , &count );
      
      for ( i = 0; i < count; i++ ) {
        NSString *propertyName = [NSString stringWithUTF8String: property_getName(classProperties[i])];
        if ([propertyName hasPrefix:@"accessibility"] == YES || [propertyName isEqualToString:@"isAccessibilityElement"] == YES) {
          continue;
        }
        
        NSString *propertyType = [NSString stringWithUTF8String: property_getTypeString(classProperties[i])];
        BOOL mutable = [writablePropertyTypes containsObject:propertyType];
        BOOL wasThrown = NO;
        
        id aValue = nil;
        @try {
          aValue = [object valueForKeyPath:propertyName];
        }
        @catch (id e) {
          wasThrown = YES;
          aValue = e;
        }
        
        PDRuntimePropertyDescriptor *descriptor = [self newRuntimePropertyDescriptorForObject:aValue
                                                                                       withId:[NSString stringWithFormat:@"(%@ %@)", objectId, propertyName]
                                                                                         name:propertyName
                                                                                      mutable:mutable];
        descriptor.wasThrown = [NSNumber numberWithBool:wasThrown];
        [results addObject:descriptor];
      }
      free(classProperties);
      objectClass = [objectClass superclass];
    }
  }
  
  callback(results, nil);
}

// Releases remote object with given id.
// Param objectId: Identifier of the object to release.
- (void)domain:(PDRuntimeDomain *)domain
releaseObjectWithObjectId:(NSString *)objectId
      callback:(void (^)(id error))callback
{
  NSLog(@"%s", __PRETTY_FUNCTION__);
  NSLog(@"domain=%@", domain);
  NSLog(@"objectId=%@", objectId);
  NSLog(@"callback=%@", callback);
  callback(nil);
}

// Releases all remote objects that belong to a given group.
// Param objectGroup: Symbolic object group name.
- (void)domain:(PDRuntimeDomain *)domain
releaseObjectGroupWithObjectGroup:(NSString *)objectGroup
      callback:(void (^)(id error))callback
{
  NSLog(@"%s", __PRETTY_FUNCTION__);
  NSLog(@"domain=%@", domain);
  NSLog(@"objectGroup=%@", objectGroup);
  NSLog(@"callback=%@", callback);
  callback(nil);
}

// Tells inspected instance(worker or page) that it can run in case it was started paused.
- (void)domain:(PDRuntimeDomain *)domain
runWithCallback:(void (^)(id error))callback
{
  NSLog(@"%s %@ %@", __PRETTY_FUNCTION__, domain, callback);
  callback(nil);
}

// Enables reporting about creation of isolated contexts by means of <code>isolatedContextCreated</code> event. When the reporting gets enabled the event will be sent immediately for each existing isolated context.
// Param enabled: Reporting enabled state.
- (void)domain:(PDRuntimeDomain *)domain
setReportExecutionContextCreationWithEnabled:(NSNumber *)enabled
      callback:(void (^)(id error))callback
{
  NSLog(@"%s %@ %@ %@", __PRETTY_FUNCTION__, domain, enabled, callback);
  callback(nil);
}

@end
