//
//  PDFScriptRuntimeDomainController.h
//  PonyDebugger
//
//  Created by Steve White on 9/8/12.
//
//  Licensed to Square, Inc. under one or more contributor license agreements.
//  See the LICENSE file distributed with this work for the terms under
//  which Square, Inc. licenses this file to you.
//

#import <PonyDebugger/PDDomainController.h>
#import <PonyDebugger/PDRuntimeDomain.h>
#import <PonyDebugger/PDRuntimeTypes.h>

@interface PDFScriptRuntimeDomainController : PDDomainController <PDRuntimeCommandDelegate>

@property (nonatomic, strong) PDRuntimeDomain *domain;

+ (PDFScriptRuntimeDomainController *)defaultInstance;

@end
