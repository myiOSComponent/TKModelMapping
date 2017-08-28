//
//  TKTarget_ORM.m
//  Pods
//
//  Created by 云峰李 on 2017/8/25.
//
//

#import "TKTargetORM.h"
#import "GPModel.h"

static NSString* const kModelORMClass = @"ORMClass";
static NSString* const kModelJsonContent = @"ORMContent";
static NSString* const kModelORMObject = @"ORMObject";
static NSString* const kModelORMObject1 = @"ORMObject1";
static NSString* const kModelORMCoder = @"ORMCoder";

static NSString* const kClassMethodInfo = @"methodInfo";
static NSString* const kClassPropertyInfo = @"propertyInfo";

@implementation TKTargetORM

- (id)tkAction_modelWithJSON:(NSDictionary *)params
{
    Class modelClass = params[kModelORMClass];
    id json = params[kModelJsonContent];
    return [modelClass gpModelWithJSON:json];
}

- (NSArray *)tkAction_modelListWithJSON:(NSDictionary *)params
{
    Class modelClass = params[kModelORMClass];
    id json = params[kModelJsonContent];
    return [modelClass gpModelListWithJSON:json];
}

- (NSDictionary *)tkAction_modelDictionaryWithJson:(NSDictionary *)params
{
    Class modelClass = params[kModelORMClass];
    id json = params[kModelJsonContent];
    return [modelClass gpModelDictionaryWithJson:json];
}

- (BOOL)tkAction_modelSetWithJSON:(NSDictionary *)params
{
    id model = params[kModelORMObject];
    id json = params[kModelJsonContent];
    return [model gpModelSetWithJSON:json];
}

- (id)tkAction_modelToJSONObject:(NSDictionary *)params
{
    id model = params[kModelORMObject];
    return [model gpModelToJSONObject];
}

- (NSData *)tkAction_modelToJSONData:(NSDictionary *)params
{
    id model = params[kModelORMObject];
    return [model gpModelToJSONData];
}

- (NSString *)tkAction_modelToJSONString:(NSDictionary *)params
{
    id model = params[kModelORMObject];
    return [model gpModelToJSONString];
}

- (id)tkAction_modelCopy:(NSDictionary *)params
{
    id model = params[kModelORMObject];
    return [model gpModelCopy];
}

- (void)tkAction_modelEncodeWithCoder:(NSDictionary *)aCoder
{
    NSCoder* coder = aCoder[kModelORMCoder];
    id model = aCoder[kModelORMObject];
    return [model gpModelEncodeWithCoder:coder];
}

- (id)tkAction_modelInitWithCoder:(NSDictionary *)aCoder
{
    NSCoder* coder = aCoder[kModelORMCoder];
    id model = aCoder[kModelORMObject];
    return [model gpModelInitWithCoder:coder];
}

- (BOOL)tkAction_modelIsEqual:(NSDictionary *)params
{
    id model = params[kModelORMObject];
    id model1 = params[kModelORMObject1];
    return [model gpModelIsEqual:model1];
}

- (NSDictionary *)tkAction_classInfo:(NSDictionary *)params
{
    Class modelClass = params[kModelORMClass];
    
    NSMutableDictionary* retClassInfo = [NSMutableDictionary new];
    GPModelClassInfo* classInfo = [GPModelClassInfo classInfoWithClass:modelClass];
    
    NSLog(@"方法列表:%@",classInfo.methodInfos);
    if (classInfo.methodInfos) {
        retClassInfo[kClassMethodInfo] = classInfo.methodInfos.allKeys;
    }
    
    NSLog(@"属性列表:%@",classInfo.propertyInfos);
    if (classInfo.propertyInfos) {
        retClassInfo[kClassPropertyInfo] = classInfo.propertyInfos.allKeys;
    }
    
    return [retClassInfo copy];
}

@end
