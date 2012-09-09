//
//  PDASLConsoleDomainController.h
//  PonyDebugger
//
//  Created by Steve White on 9/9/12.
//
//

#import <PonyDebugger/PDDomainController.h>
#import <PonyDebugger/PDConsoleDomain.h>
#import <PonyDebugger/PDConsoleTypes.h>

@interface PDASLConsoleDomainController : PDDomainController <PDConsoleCommandDelegate>

@property (nonatomic, strong) PDConsoleDomain *domain;

+ (PDASLConsoleDomainController *)defaultInstance;

@end
