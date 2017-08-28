//
//  TKTarget_ORM.h
//  Pods
//
//  Created by 云峰李 on 2017/8/25.
//
//

#import <Foundation/Foundation.h>

/**
 动态对象影射转换工具
 */
@interface TKTargetORM : NSObject
   
- (id)tkAction_modelWithJSON:(NSDictionary *)params;

- (NSArray *)tkAction_modelListWithJSON:(NSDictionary *)params;
- (NSDictionary *)tkAction_modelDictionaryWithJson:(NSDictionary *)params;

- (BOOL)tkAction_modelSetWithJSON:(NSDictionary *)params;

- (id)tkAction_modelToJSONObject:(NSDictionary *)params;
- (NSData *)tkAction_modelToJSONData:(NSDictionary *)params;
- (NSString *)tkAction_modelToJSONString:(NSDictionary *)params;

- (id)tkAction_modelCopy:(NSDictionary *)params;

- (void)tkAction_modelEncodeWithCoder:(NSDictionary *)aCoder;
- (id)tkAction_modelInitWithCoder:(NSDictionary *)aCoder;

- (BOOL)tkAction_modelIsEqual:(NSDictionary *)params;

/**
 获取类型信息，包括对应方法(类方法，实例方法)，对应属性(没有setter方法的不会显示)
 
 @param params class 参数
 @return 返回类型信息
 */
- (NSDictionary *)tkAction_classInfo:(NSDictionary *)params;
    
@end
