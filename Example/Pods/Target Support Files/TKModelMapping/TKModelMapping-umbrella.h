#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "GPModel.h"
#import "GPModelClassInfo.h"
#import "NSObject+GPModel.h"
#import "TKTargetORM.h"

FOUNDATION_EXPORT double TKModelMappingVersionNumber;
FOUNDATION_EXPORT const unsigned char TKModelMappingVersionString[];

