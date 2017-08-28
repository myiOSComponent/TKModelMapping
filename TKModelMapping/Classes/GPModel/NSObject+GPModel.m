//
//  NSObject+GPModel.m
//  GPModel
//
//  Created by feng on 15/12/29.
//  Copyright © 2015年 feng. All rights reserved.
//

#import "NSObject+GPModel.h"
#import "GPModelClassInfo.h"
#import <libkern/OSAtomic.h> //原子性
#import <objc/message.h>

#define force_inline __inline__ __attribute__((always_inline)) //强制内链

//设置属性值
#define SETVALUE(__TYPE__,__MODEL__,__SEL__,__VALUE__)  ((void (*)(id,SEL,__TYPE__))(void *)objc_msgSend)(__MODEL__,__SEL__,__VALUE__)
#define GETVALUE(__TYPE__,__MODEL__,__SEL__) ((__TYPE__(*)(id,SEL))(void *)objc_msgSend)(__MODEL__,__SEL__)



/**
 *  获取NSFoundatioin 类型
 *
 *  @param cls Class
 *
 *  @return 返回GPEncodingType
 */
GPEncodingNSType GetNSType(Class cls)
{
    if (!cls) return GPEncodingNSTypeUnknown;
    if ([cls isSubclassOfClass:[NSString class]]) return GPEncodingNSTypeNSString;
    if ([cls isSubclassOfClass:[NSMutableString class]]) return GPEncodingNSTypeNSMutableString;
    if ([cls isSubclassOfClass:[NSValue class]]) return GPEncodingNSTypeNSValue;
    if ([cls isSubclassOfClass:[NSNumber class]]) return GPEncodingNSTypeNSNumber;
    if ([cls isSubclassOfClass:[NSDecimalNumber class]]) return GPEncodingNSTypeNSDecimalNumber;
    if ([cls isSubclassOfClass:[NSData class]]) return GPEncodingNSTypeNSData;
    if ([cls isSubclassOfClass:[NSMutableData class]]) return GPEncodingNSTypeNSMutableData;
    if ([cls isSubclassOfClass:[NSDate class]]) return GPEncodingNSTypeNSDate;
    if ([cls isSubclassOfClass:[NSURL class]]) return GPEncodingNSTypeNSURL;
    if ([cls isSubclassOfClass:[NSArray class]]) return GPEncodingNSTypeNSArray;
    if ([cls isSubclassOfClass:[NSMutableArray class]]) return GPEncodingNSTypeNSMutableArray;
    if ([cls isSubclassOfClass:[NSDictionary class]]) return GPEncodingNSTypeNSDictionary;
    if ([cls isSubclassOfClass:[NSMutableDictionary class]]) return GPEncodingNSTypeNSMutableDictionary;
    if ([cls isSubclassOfClass:[NSSet class]]) return GPEncodingNSTypeNSSet;
    if ([cls isSubclassOfClass:[NSMutableSet class]]) return GPEncodingNSTypeNSMutableSet;
    return GPEncodingNSTypeUnknown;
}

/**
 *  判断类型是否为C内置类型
 *
 *  @param type 类型
 *
 *  @return 如果是内置类型为true,如果不是内置类型为false.
 */
BOOL GPEncodingTypeIsCNumber(GPEncodingType type)
{
    switch (type & GPEncodingTypeMask) {
        case GPEncodingTypeBool:
        case GPEncodingTypeInt8:
        case GPEncodingTypeUInt8:
        case GPEncodingTypeInt16:
        case GPEncodingTypeUInt16:
        case GPEncodingTypeInt32:
        case GPEncodingTypeUInt32:
        case GPEncodingTypeInt64:
        case GPEncodingTypeUInt64:
        case GPEncodingTypeFloat:
        case GPEncodingTypeDouble:
        case GPEncodingTypeLongDouble:
            return YES;
        default:return NO;
    }
}

/**
 *  将传递进来的未知类型转换成NSNumber
 *
 *  @param value 位置类型值
 *
 *  @return A number,or nil if some error occurs.
 */
static force_inline NSNumber* GPConvertNSNumberFormID(__unsafe_unretained id value)
{
    static NSCharacterSet* dot; //  用于判断是否有小数
    static NSDictionary* dic;   //  存储可能的字符集合
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dot = [NSCharacterSet characterSetWithRange:NSMakeRange('.', 1)];
        dic = @{@"TRUE" :   @(YES),
                @"True" :   @(YES),
                @"true" :   @(YES),
                @"FALSE" :  @(NO),
                @"False" :  @(NO),
                @"false" :  @(NO),
                @"YES" :    @(YES),
                @"Yes" :    @(YES),
                @"yes" :    @(YES),
                @"NO" :     @(NO),
                @"No" :     @(NO),
                @"no" :     @(NO),
                @"NIL" :    (id)kCFNull,
                @"Nil" :    (id)kCFNull,
                @"nil" :    (id)kCFNull,
                @"NULL" :   (id)kCFNull,
                @"Null" :   (id)kCFNull,
                @"null" :   (id)kCFNull,
                @"(NULL)" : (id)kCFNull,
                @"(Null)" : (id)kCFNull,
                @"(null)" : (id)kCFNull,
                @"<NULL>" : (id)kCFNull,
                @"<Null>" : (id)kCFNull,
                @"<null>" : (id)kCFNull};
    });
    
    if (!value || value == (id)kCFNull) return nil;
    if ([value isKindOfClass:[NSNumber class]]) return value;
    if ([value isKindOfClass:[NSString class]]) {
        NSNumber* number = dic[value];
        if (number) {
            if (number == (id)kCFNull) {
                return nil;
            }
            return number;
        }
        //判断是否为小数
        NSString* string = (NSString *)value;
        const char* cstring = string.UTF8String;
        if (!cstring) return nil;
        if ([string rangeOfCharacterFromSet:dot].location != NSNotFound) {
            double num = atof(cstring);
            if (isnan(num) || isinf(num)) return nil;
            return @(num);
        }else
        {
            return @(atoll(cstring));
        }
    }
    return nil;
}

/**
 *  根据日期格式返回日期格式对象
 *
 *  @param dateFomat string fromat
 *
 *  @return 日期转换对象
 */
static force_inline NSDateFormatter* GPConvertDateFormatter(NSString* dateFomat)
{
    if (!dateFomat) return nil;
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    formatter.dateFormat = dateFomat;
    return formatter;
}

/**
 *  将NSDate 转换成国际标准的日期格式
 *
 *  @param date 日期
 *
 *  @return string,如果有错误发生则返回nil.
 */
static force_inline NSString* GPISODateString(NSDate* date)
{
    if (!date) return nil;
    NSDateFormatter* dateFomater = GPConvertDateFormatter(@"yyyy-MM-dd'T'HH:mm:ssZ");
    return [dateFomater stringFromDate:date];
}

/**
 *  将日期字符串，转换成NSDate
 *
 *  @param string 日期字符串
 *
 *  @return 日期
 */
static force_inline NSDate* GPConvertNSDateFromString(__unsafe_unretained NSString *string)
{
    typedef NSDate* (^GPNSDateParseBlock)(NSString* dateString);
    static NSDictionary<NSNumber*,GPNSDateParseBlock>* blocks; //key:字符长度,block:日期转换block
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        {
            // 2015-12-10 //字符长度刚好10个
            NSDateFormatter* formatter10 = GPConvertDateFormatter(@"yyyy-MM-dd");
            GPNSDateParseBlock block10 = ^(NSString *string) {return [formatter10 dateFromString:string];};
            // 2015-12-10T11:53:32 //字符长度刚好19
            NSDateFormatter* formatterT19 = GPConvertDateFormatter(@"yyyy-MM-dd'T'HH:mm:ss");
            // 2015-12-10 11:53:32 //字符长度刚好19
            NSDateFormatter* formatter19  = GPConvertDateFormatter(@"yyyy-MM-dd HH:mm:ss");
            GPNSDateParseBlock block19 = ^(NSString *string){
                if ([string characterAtIndex:10] == 'T') {
                    return [formatterT19 dateFromString:string];
                }else
                {
                    return [formatter19 dateFromString:string];
                }
            };
            // 2015-12-10T11:53:32Z //字符为20
            // 2015-12-10T11:53:32+0800 //字符为24
            // 2015-12-10T11:53:32+12:00 //字符为25
            NSDateFormatter* formatter2025 = GPConvertDateFormatter(@"yyyy-MM-dd'T'HH:mm:ssZ");
            GPNSDateParseBlock block20 = ^(NSString *string){return [formatter2025 dateFromString:string];};
            GPNSDateParseBlock block24 = ^(NSString *string){return [formatter2025 dateFromString:string];};
            GPNSDateParseBlock block25 = ^(NSString *string){return [formatter2025 dateFromString:string];};
            // fri sep 04 00:12:21 +0800 2015 //字符30
            NSDateFormatter* formatter30 = GPConvertDateFormatter(@"EEE MMM dd HH:mm:ss Z yyyy");
            GPNSDateParseBlock block30 = ^(NSString* string){return [formatter30 dateFromString:string];};
            
            blocks = @{@(10):block10,
                       @(19):block19,
                       @(20):block20,
                       @(24):block24,
                       @(25):block25,
                       @(30):block30};
        }
    });
    if (!string) return nil;
    GPNSDateParseBlock parser = blocks[@(string.length)];
    if (!parser) return nil;
    return parser(string);
}

///**
// *  获取block的对象类型
// *
// *  @return block类型
// */
//static force_inline Class GPNSBlockClass()
//{
//    static Class cls;
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        void (^block)(void) = ^{};
//        cls = ((NSObject *) block).class;
//        //找到继承体系中最上面一个不是NSObject的类型
//        while (class_getSuperclass(cls) != [NSObject class]) {
//            cls = class_getSuperclass(cls);
//        }
//    });
//    return cls;
//}

/**
 *  根据keyPaths获取dic中的值
 *
 *  @param dic      持有值得字典
 *  @param keyPaths key.
 *
 *  @return value
 */
static force_inline id GPValueForKeyPath(__unsafe_unretained NSDictionary* dic,__unsafe_unretained NSArray* keyPaths)
{
    __block id value = nil;
    for (NSUInteger idx = 0, max = keyPaths.count; idx < max; ++idx) {
        value = dic[keyPaths[idx]];
        if (idx + 1 < max) {
            if ([value isKindOfClass:[NSDictionary class]]) {
                dic = value;
            }else
            {
                return nil;
            }
        }
    }
    return value;
}

/**
 *  根据Key获取value
 *
 *  @param dic 持有值得字典
 *  @param multiKeys key数组
 *
 *  @return 获取值
 */
static force_inline id GPValueForMultiKeys(__unsafe_unretained NSDictionary* dic,__unsafe_unretained NSArray* multiKeys)
{
    id value = nil;
    for (NSString* key in multiKeys) {
        if ([key isKindOfClass:[NSString class]]) {
            value = dic[key];
            if (value) break;
        }else
        {
            value = GPValueForKeyPath(dic, (NSArray*)key);
            if (value) break;
        }
    }
    return value;
}

@implementation p_GPModelPropertyMeta

+ (instancetype)metaWithClassInfo:(GPModelClassInfo *)classInfo propertyInfo:(GPClassPropertyInfo *)propertyInfo genericClass:(Class)genericCls
{
    p_GPModelPropertyMeta* meta = [self new];
    //设置元数据，基本信息
    meta.name = propertyInfo.name; //  名字
    meta.type = propertyInfo.type; //  类型
    meta.info = propertyInfo;      //  信息
    meta.genericCls = genericCls;  //  容器容纳的类型
    [genericCls new];
    //如果是对象类型
    if ((meta->_type & GPEncodingTypeMask) == GPEncodingTypeObject) {
        meta->_nsType = GetNSType(propertyInfo.cls);
    }else{
        meta->_isCNumber = GPEncodingTypeIsCNumber(propertyInfo.type);
    }
    //判断是否为结构体
    if ((meta->_type & GPEncodingTypeMask) == GPEncodingTypeStruct) {
        static NSSet* types = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSMutableSet* set = [NSMutableSet new];
            // 32 bit
            [set addObject:@"{CGSize=ff}"];
            [set addObject:@"{CGPoint=ff}"];
            [set addObject:@"{CGRect={CGPoint=ff}{CGSize=ff}}"];
            [set addObject:@"{CGAffineTransform=ffffff}"];
            [set addObject:@"{UIEdgeInsets=ffff}"];
            [set addObject:@"{UIOffset=ff}"];
            // 64 bit
            [set addObject:@"{CGSize=dd}"];
            [set addObject:@"{CGPoint=dd}"];
            [set addObject:@"{CGRect={CGPoint=dd}{CGSize=dd}}"];
            [set addObject:@"{CGAffineTransform=dddddd}"];
            [set addObject:@"{UIEdgeInsets=dddd}"];
            [set addObject:@"{UIOffset=dd}"];
            types = [set copy];
        });
        meta->_isStructAvailableForKeyedArchiver = [types containsObject:propertyInfo.typeEncoding];
    }
    
    //判断是否需要从自定义类型字典中生成对象类型
    meta->_cls = propertyInfo.cls;
    if (genericCls) {
        meta->_hasCustomClassFromDictionary = [genericCls respondsToSelector:@selector(gpModelCustomClassForDictionary:)];
    }else if(meta->_cls && meta->_nsType == GPEncodingNSTypeUnknown){
        meta->_hasCustomClassFromDictionary = [meta->_cls respondsToSelector:@selector(gpModelCustomClassForDictionary:)];
    }
    
    //getter and setter.
    if (propertyInfo.getter) {
        SEL sel = NSSelectorFromString(propertyInfo.getter);
        if ([classInfo.cls instancesRespondToSelector:sel]) {
            meta->_getter = sel;
        }
    }
    
    if (propertyInfo.setter) {
        SEL sel = NSSelectorFromString(propertyInfo.setter);
        if ([classInfo.cls instancesRespondToSelector:sel]) {
            meta->_setter = sel;
        }
    }
    
    if (meta->_getter && meta->_setter) {
        //long double ,指针类型，不可用在kvc上
        switch (meta->_type & GPEncodingTypeMask) {
            case GPEncodingTypeBool:
            case GPEncodingTypeInt8:
            case GPEncodingTypeUInt8:
            case GPEncodingTypeInt16:
            case GPEncodingTypeUInt16:
            case GPEncodingTypeInt32:
            case GPEncodingTypeUInt32:
            case GPEncodingTypeInt64:
            case GPEncodingTypeUInt64:
            case GPEncodingTypeFloat:
            case GPEncodingTypeDouble:
            case GPEncodingTypeObject:
            case GPEncodingTypeClass:
            case GPEncodingTypeBlock:
            case GPEncodingTypeStruct:
            case GPEncodingTypeUnion:
                meta->_isKvcCompatible = YES;
                break;
            default:
                meta->_isKvcCompatible = NO;
                break;
        }
    }
    return meta;
}

@end

@implementation p_GPModelMeta

- (instancetype)initWithClass:(Class)cls
{
    //创建类信息
    GPModelClassInfo* classInfo = [GPModelClassInfo classInfoWithClass:cls];
    if (!classInfo) return nil;
    
    self = [super init];
    if (self) {
        //黑名单
        NSSet* blackList = nil;
        if ([cls respondsToSelector:@selector(gpModelPropertyBlacklist)]) {
            NSArray* properties = [(id<GPModel>)cls gpModelPropertyBlacklist];
            if (properties) {
                blackList = [NSSet setWithArray:properties];
            }
        }
        
        NSDictionary* genericMapper = nil;
        if ([cls respondsToSelector:@selector(gpModelContainerPropertyClassMapper)]) {
            genericMapper = [(id<GPModel>)cls gpModelContainerPropertyClassMapper];
            if (genericMapper) {
                NSMutableDictionary* tmpDic = [NSMutableDictionary new];
                [genericMapper enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                    //Key只能为string.
                    if (![key isKindOfClass:[NSString class]]) return ;
                    //获取obj的类型
                    Class meta = object_getClass(obj);
                    if (!meta) return;
                    if (class_isMetaClass(meta)) {
                        tmpDic[key] = obj;
                    }else if([obj isKindOfClass:[NSString class]])
                    {
                        Class cls = NSClassFromString(obj);
                        if (cls) {
                            tmpDic[key] = cls;
                        }
                    }
                }];
                genericMapper = tmpDic;  //防止无意识的修改
            }
        }
        
        //创建属性元数据
        NSMutableDictionary* allPropertyMetas = [NSMutableDictionary new];
        GPModelClassInfo* curClassInfo = classInfo;
        //遍历解析属性的类以及父类，知道root类
        while (curClassInfo && curClassInfo.superCls != nil) {
            for (GPClassPropertyInfo* propertyInfo in curClassInfo.propertyInfos.allValues) {
                if (!propertyInfo.name) continue;
                //检测黑名单
                if (blackList && [blackList containsObject:propertyInfo.name]) continue;
                p_GPModelPropertyMeta* propertyMeta = [p_GPModelPropertyMeta metaWithClassInfo:curClassInfo
                                                                                  propertyInfo:propertyInfo
                                                                                  genericClass:genericMapper[propertyInfo.name]];
                if (!propertyMeta) continue;
                if (!propertyMeta.getter && !propertyMeta.setter) continue;
                if (allPropertyMetas[propertyMeta.name]) continue;
                allPropertyMetas[propertyMeta.name] = propertyMeta;
            }
            curClassInfo = curClassInfo.superClassInfo;
        }
        if (allPropertyMetas.count > 0) {
            _allPropertyMetas = [allPropertyMetas.allValues copy];
        }
        
        //创建映射
        NSMutableDictionary* mapper = [NSMutableDictionary new];
        NSMutableArray* keyPathPropertyMetas = [NSMutableArray new];
        NSMutableArray* multiKeysPropertyMetas = [NSMutableArray new];
        if ([cls respondsToSelector:@selector(gpModelCustomPropertyMapper)]) {
            NSDictionary* customMapper = [(id<GPModel>)cls gpModelCustomPropertyMapper];
            [customMapper enumerateKeysAndObjectsUsingBlock:^(NSString* propertyName, id mappedToKey, BOOL * _Nonnull stop) {
                p_GPModelPropertyMeta* propertyMeta = allPropertyMetas[propertyName];
                if (!propertyMeta) return;
                //删除现有的属性信息
                [allPropertyMetas removeObjectForKey:propertyName];
                //创建新的属性映射
                if ([mappedToKey isKindOfClass:[NSString class]]) {
                    NSString* mappedKey = (NSString *)mappedToKey;
                    if (mappedKey.length == 0) return;
                    propertyMeta.mappedToKey = mappedKey;
                    NSArray* keyPath = [mappedKey componentsSeparatedByString:@"."];//如果key为 user.name
                    if (keyPath.count > 1) {
                        propertyMeta.mappedToKeyPath = keyPath;
                        [keyPathPropertyMetas addObject:keyPath];
                    }
                    propertyMeta.next = mapper[mappedToKey] ?: nil;
                    mapper[mappedToKey] = propertyMeta;
                }else if([mappedToKey isKindOfClass:[NSArray class]]){
                    NSMutableArray* mappedToKeyArray = [NSMutableArray new];
                    for (NSString* key in (NSArray*)mappedToKey) {
                        if (![key isKindOfClass:[NSString class]] ||
                            key.length == 0) {
                            continue;
                        }
                        
                        NSArray* keyPath = [key componentsSeparatedByString:@"."];
                        if (keyPath.count > 1) {
                            [mappedToKeyArray addObject:keyPath];
                        }else{
                            [mappedToKeyArray addObject:key];
                        }
                        
                        if (!propertyMeta.mappedToKey) {
                            propertyMeta.mappedToKey = key;
                            propertyMeta.mappedToKeyPath = keyPath.count > 1 ? keyPath : nil;
                        }
                    }
                    if (!propertyMeta.mappedToKey) return;
                    
                    propertyMeta.mappedToKeyArray = [mappedToKeyArray copy];
                    [multiKeysPropertyMetas addObject:propertyMeta];
                    
                    propertyMeta.next = mapper[mappedToKey] ?: nil;
                    mapper[mappedToKey] = propertyMeta;
                }
            }];
        }
        
        [allPropertyMetas enumerateKeysAndObjectsUsingBlock:^(NSString* name, p_GPModelPropertyMeta* propertyMeta, BOOL * _Nonnull stop) {
            propertyMeta.name = name;
            propertyMeta.next = mapper[name] ?: nil;
            propertyMeta.mappedToKey = name;
            mapper[name] = propertyMeta;
        }];
        
        if (mapper.count) _mapper = mapper;
        if (keyPathPropertyMetas) _keyPathPropertyMetas = keyPathPropertyMetas;
        if (multiKeysPropertyMetas) _multiKeysPropertyMetas = multiKeysPropertyMetas;
        
        _keyMappedCount = _allPropertyMetas.count;
        _nsType = GetNSType(cls);
        _hasCustomClassFromDictionary = [cls instancesRespondToSelector:@selector(gpModelCustomClassForDictionary:)];
        
    }
    return self;
}

/**
 *  类方法，返回缓存中的类元数据
 *
 *  @param cls 类
 *
 *  @return 类信息
 */
+ (instancetype)metaWithClass:(Class)cls
{
    if (!cls) return nil;
    static CFMutableDictionaryRef cache;
    static dispatch_once_t onceToken;
    static OSSpinLock lock;//原子锁
    dispatch_once(&onceToken, ^{
        cache = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        lock = OS_SPINLOCK_INIT;
    });
    
    OSSpinLockLock(&lock); //加锁
    p_GPModelMeta* meta = CFDictionaryGetValue(cache, (__bridge const void*)cls);
    OSSpinLockUnlock(&lock); //解锁
    if (!meta) {
        meta = [[p_GPModelMeta alloc] initWithClass:cls];
        if (meta) {
            OSSpinLockLock(&lock);
            CFDictionarySetValue(cache, (__bridge const void*)cls, (__bridge const void *)meta);
            OSSpinLockUnlock(&lock);
        }
    }
    return meta;
}

@end

/**
 *  将属性中的值，转换成NSNumbeer,
 *  model以及，propertyMeta必须在函数外部有强应用，且应该在函数retrun之前一直持有，
 *  @param model        模型 ,不能为nil.
 *  @param propertyMeta 属性信息 ,不能为nil,getter方法必须有,且其isCNumber 为yes.
 *
 *  @return A NSnumber,如果有错误发生则返回nil.
 */
static force_inline NSNumber* GPModelGenerateNSNumberFromProperty(__unsafe_unretained id model,
                                                                  __unsafe_unretained p_GPModelPropertyMeta* propertyMeta)
{
    switch (propertyMeta.type & GPEncodingTypeMask) {
        case GPEncodingTypeBool:
            return @(((bool (*)(id,SEL))(void *)objc_msgSend)(model,propertyMeta.getter));
        case GPEncodingTypeInt8:
            return @(((int8_t(*)(id,SEL))(void *)objc_msgSend)(model,propertyMeta.getter));
        case GPEncodingTypeUInt8:
            return @(((uint8_t(*)(id,SEL))(void *)objc_msgSend)(model,propertyMeta.getter));
        case GPEncodingTypeInt16:
            return @(((int16_t(*)(id,SEL))(void *)objc_msgSend)(model,propertyMeta.getter));
        case GPEncodingTypeUInt16:
            return @(((uint16_t(*)(id,SEL))(void *)objc_msgSend)(model,propertyMeta.getter));
        case GPEncodingTypeInt32:
            return @(((int32_t(*)(id,SEL))(void *)objc_msgSend)(model,propertyMeta.getter));
        case GPEncodingTypeUInt32:
            return @(((uint32_t(*)(id,SEL))(void *)objc_msgSend)(model,propertyMeta.getter));
        case GPEncodingTypeInt64:
            return @(((int64_t(*)(id,SEL))(void *)objc_msgSend)(model,propertyMeta.getter));
        case GPEncodingTypeUInt64:
            return @(((uint64_t(*)(id,SEL))(void *)objc_msgSend)(model,propertyMeta.getter));
        case GPEncodingTypeFloat:
        {
            float num = ((float (*)(id,SEL))(void *)objc_msgSend)(model,propertyMeta.getter);
            if (isnan(num) || isinf(num)) return nil;
            return @(num);
        }
        case GPEncodingTypeDouble:
        {
            double num = ((double (*)(id,SEL))(void *)objc_msgSend)(model,propertyMeta.getter);
            if (isnan(num) || isinf(num)) return nil;
            return @(num);
        }
        case GPEncodingTypeLongDouble:
        {
            double num = ((long double (*)(id,SEL))(void *)objc_msgSend)(model,propertyMeta.getter);
            if (isnan(num) || isinf(num)) return nil;
            return @(num);
        }
        default:
            return nil;
    }
}

/**
 *  为属性设置C类型值,int,float ,bool等
 *
 *  @param model        模型，不能为nil
 *  @param value        值,不能为nil.
 *  @param propertyMeta 模型数据，不能为0,propertyMeta.isCNumber 必须为yes.propertyMeta.setter不能为nil.
 */
static force_inline void GPModelSetCNumberToProperty(__unsafe_unretained id model,
                                                     __unsafe_unretained NSNumber* value,
                                                     __unsafe_unretained p_GPModelPropertyMeta* propertyMeta)
{

    switch (propertyMeta.type & GPEncodingTypeMask) {
        case GPEncodingTypeBool:
            SETVALUE(bool,model,propertyMeta.setter,value.boolValue);
            break;
        case GPEncodingTypeInt8:
            SETVALUE(int8_t,model,propertyMeta.setter,value.charValue);
            break;
        case GPEncodingTypeUInt8:
            SETVALUE(uint8_t,model,propertyMeta.setter,value.unsignedCharValue);
            break;
        case GPEncodingTypeInt16:
            SETVALUE(int16_t,model,propertyMeta.setter,value.shortValue);
            break;
        case GPEncodingTypeUInt16:
            SETVALUE(uint16_t,model,propertyMeta.setter,value.unsignedShortValue);
            break;
        case GPEncodingTypeInt32:
            SETVALUE(int32_t, model, propertyMeta.setter, value.intValue);
            break;
        case GPEncodingTypeUInt32:
            SETVALUE(uint32_t, model, propertyMeta.setter, value.unsignedIntValue);
            break;
        case GPEncodingTypeInt64:{
            if ([value isKindOfClass:[NSDecimalNumber class]]) {
                SETVALUE(int64_t, model, propertyMeta.setter, value.stringValue.longLongValue);
            }else{
                SETVALUE(uint64_t, model, propertyMeta.setter, value.longLongValue);
            }
        }
            break;
        case GPEncodingTypeUInt64:{
            if ([value isKindOfClass:[NSDecimalNumber class]]) {
                SETVALUE(int64_t, model, propertyMeta.setter, value.stringValue.longLongValue);
            }else {
                SETVALUE(uint64_t, model, propertyMeta.setter, value.unsignedLongLongValue);
            }
        }
            break;
        case GPEncodingTypeFloat:{
            float floatValue = value.floatValue;
            if (isnan(floatValue) || isinf(floatValue)) {
                floatValue = 0;
            }
            SETVALUE(float, model, propertyMeta.setter, floatValue);
        }
            break;
        case GPEncodingTypeDouble:{
            double doubleValue = value.doubleValue;
            if (isnan(doubleValue) || isinf(doubleValue)) {
                doubleValue = 0;
            }
            SETVALUE(double, model, propertyMeta.setter, doubleValue);
        }
            break;
        case GPEncodingTypeLongDouble:{
            long double ldValue = value.doubleValue;
            if (isnan(ldValue) || isinf(ldValue)) {
                ldValue = 0;
            }
            SETVALUE(long double, model, propertyMeta.setter, ldValue);
        }
        default:
            break;
    }
}

/**
 *  通过属性元数据设置模型的属性值
 *
 *  @param model        模型,不能为nil.
 *  @param value        值,不能为nil,但是其类型可为NSNil
 *  @param propertyMeta 属性元数据，不能为nil,propertyMeta.setter 不能为nil
 */
static void GPModelSetValueForProperty(__unsafe_unretained id model,
                                       __unsafe_unretained id value,
                                       __unsafe_unretained p_GPModelPropertyMeta* propertyMeta)
{
    if (propertyMeta.isCNumber) {
        NSNumber* number = GPConvertNSNumberFormID(value);
        GPModelSetCNumberToProperty(model, number, propertyMeta);
    }else if(propertyMeta.nsType) {
        if (value == (id)kCFNull) {
            SETVALUE(id, model, propertyMeta.setter, nil);
        }else{
            switch (propertyMeta.nsType) {
                case GPEncodingNSTypeNSString:
                case GPEncodingNSTypeNSMutableString:{
                    if ([value isKindOfClass:[NSString class]]) {
                        SETVALUE(id, model, propertyMeta.setter,
                                 (propertyMeta.nsType == GPEncodingNSTypeNSString) ? value : [(NSString *)value mutableCopy]);
                    }else if ([value isKindOfClass:[NSNumber class]]){
                        NSString* stringValue = ((NSNumber *)value).stringValue;
                        if ([stringValue rangeOfString:@"."].length > 0) { //小数
                            stringValue = [NSString stringWithFormat:@"%.2f",[stringValue floatValue]];
                        }
                        SETVALUE(id, model, propertyMeta.setter,
                                 (propertyMeta.nsType == GPEncodingNSTypeNSString) ? stringValue : [stringValue mutableCopy]);
                    }else if ([value isKindOfClass:[NSData class]]){
                        NSString* string = [[NSString alloc] initWithData:value encoding:NSUTF8StringEncoding];
                        SETVALUE(id, model, propertyMeta.setter,
                                 (propertyMeta.nsType == GPEncodingNSTypeNSString) ? string : [string mutableCopy]);
                    }else if([value isKindOfClass:[NSAttributedString class]]){
                        SETVALUE(id, model, propertyMeta.setter,
                                 (propertyMeta.nsType == GPEncodingNSTypeNSString) ? ((NSAttributedString *)value).string : [((NSAttributedString *)value).string mutableCopy]);
                    }
                }
                    break;
                case GPEncodingNSTypeNSValue:{
                    if ([value isKindOfClass:[NSValue class]]) {
                        SETVALUE(id, model, propertyMeta.setter, value);
                    }
                }
                    break;
                case GPEncodingNSTypeNSNumber:
                    SETVALUE(id, model, propertyMeta.setter, GPConvertNSNumberFormID(value));
                    break;
                case GPEncodingNSTypeNSDecimalNumber:{
                    if ([value isKindOfClass:[NSDecimalNumber class]]) {
                        SETVALUE(id, model, propertyMeta.setter, value);
                    }else if ([value isKindOfClass:[NSNumber class]]){
                        NSDecimalNumber* decNum = [NSDecimalNumber decimalNumberWithDecimal:((NSNumber *)value).decimalValue];
                        SETVALUE(id, model, propertyMeta.setter, decNum);
                    }else if ([value isKindOfClass:[NSString class]]){
                        NSDecimalNumber* decNum = [NSDecimalNumber decimalNumberWithString:value];
                        NSDecimal dec = decNum.decimalValue;
                        if (dec._length == 0 || dec._isNegative) {
                            decNum = nil;
                        }
                        SETVALUE(id, model, propertyMeta.setter, decNum);
                    }
                }
                    break;
                case GPEncodingNSTypeNSData:
                case GPEncodingNSTypeNSMutableData:{
                    if ([value isKindOfClass:[NSData class]]) {
                        SETVALUE(id, model, propertyMeta.setter,
                                 (propertyMeta.nsType == GPEncodingNSTypeNSData) ? value : [((NSData *)value) mutableCopy]);
                    }else if([value isKindOfClass:[NSString class]]){
                        NSData* data = [(NSString*)value dataUsingEncoding:NSUTF8StringEncoding];
                        SETVALUE(id, model, propertyMeta.setter,
                                 (propertyMeta.nsType == GPEncodingNSTypeNSData) ? data : data.mutableCopy);
                    }
                }
                    break;
                case GPEncodingNSTypeNSDate:{
                    if ([value isKindOfClass:[NSDate class]]) {
                        SETVALUE(id, model, propertyMeta.setter,value);
                    }else if([value isKindOfClass:[NSString class]]){
                        SETVALUE(id, model, propertyMeta.setter, GPConvertNSDateFromString(value));
                    }
                }
                    break;
                case GPEncodingNSTypeNSURL:{
                    if ([value isKindOfClass:[NSURL class]]) {
                        SETVALUE(id, model, propertyMeta.setter, value);
                    }else if([value isKindOfClass:[NSString class]]){
                        NSCharacterSet* characterSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
                        NSString* string = [value stringByTrimmingCharactersInSet:characterSet];
                        SETVALUE(id, model, propertyMeta.setter,
                                 (string.length == 0) ? nil : [NSURL URLWithString:string]);
                    }
                }
                    break;
                case GPEncodingNSTypeNSArray:
                case GPEncodingNSTypeNSMutableArray:{
                    //判断是否有容器所持对象的类型
                    if (propertyMeta.genericCls) {
                        NSArray* valueArray = nil;
                        if ([value isKindOfClass:[NSArray class]]) {
                            valueArray = value;
                        }else if([value isKindOfClass:[NSSet class]]){
                            valueArray = [(NSSet *)value allObjects];
                        }
                        
                        if (valueArray) {
                            NSMutableArray* objectArray = [NSMutableArray new];
                            for (id item in valueArray) {
                                if ([item isKindOfClass:propertyMeta.genericCls]) {
                                    [objectArray addObject:item];
                                }else if([item isKindOfClass:[NSDictionary class]]){
                                    Class cls = propertyMeta.genericCls;
                                    if (propertyMeta.hasCustomClassFromDictionary) {
                                        cls = [cls gpModelCustomClassForDictionary:item];
                                        if (!cls) cls = propertyMeta.genericCls;
                                    }
                                    NSObject* newObj = [cls new];
                                    [newObj gpModelSetWithDictionary:item];
                                    if (newObj) [objectArray addObject:newObj];
                                }
                            }
                            SETVALUE(id, model, propertyMeta.setter,
                                     (propertyMeta.nsType == GPEncodingNSTypeNSArray) ? [objectArray copy]: objectArray);
                        }
                    }else{
                        if ([value isKindOfClass:[NSArray class]]) {
                            SETVALUE(id, model, propertyMeta.setter,
                                     (propertyMeta.nsType == GPEncodingNSTypeNSArray) ? value : [(NSArray *)value mutableCopy]);
                        }else if([value isKindOfClass:[NSSet class]]){
                            SETVALUE(id, model, propertyMeta.setter,
                                     (propertyMeta.nsType == GPEncodingNSTypeNSArray) ? [(NSSet*)value allObjects]:[(NSSet*)value allObjects].mutableCopy);
                        }
                    }
                }
                    break;
                case GPEncodingNSTypeNSDictionary:
                case GPEncodingNSTypeNSMutableDictionary:{
                    if ([value isKindOfClass:[NSDictionary class]]) {
                        if (propertyMeta.genericCls) {
                            NSMutableDictionary* itemDic = [NSMutableDictionary new];
                            NSDictionary* valueDic = (NSDictionary *)value;
                            [valueDic enumerateKeysAndObjectsUsingBlock:^(NSString* key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                                if ([obj isKindOfClass:[NSDictionary class]]) {
                                    Class cls = propertyMeta.genericCls;
                                    if (propertyMeta.hasCustomClassFromDictionary) {
                                        cls = [cls gpModelCustomClassForDictionary:obj];
                                        if (!cls) cls = propertyMeta.genericCls;
                                    }
                                    NSObject* newObj = [cls new];
                                    [newObj gpModelSetWithDictionary:obj];
                                    if (newObj) itemDic[key] = newObj;
                                }
                            }];
                            SETVALUE(id, model, propertyMeta.setter,
                                     (propertyMeta.nsType == GPEncodingNSTypeNSDictionary) ? itemDic.copy : itemDic);
                        }else
                        {
                            SETVALUE(id, model, propertyMeta.setter,
                                     (propertyMeta.nsType == GPEncodingNSTypeNSDictionary) ? value : [(NSDictionary *)value mutableCopy]);
                        }
                    }
                }
                    break;
                case GPEncodingNSTypeNSSet:
                case GPEncodingNSTypeNSMutableSet:{
                    NSSet* valueSet = nil;
                    if ([value isKindOfClass:[NSArray class]]) valueSet = [NSSet setWithArray:value];
                    if ([value isKindOfClass:[NSSet class]]) valueSet = value;
                    if (propertyMeta.genericCls) {
                        NSMutableSet* tmpSet = [NSMutableSet new];
                        for (id item in  valueSet) {
                            if ([item isKindOfClass:propertyMeta.genericCls]) {
                                [tmpSet addObject:item];
                            }else if([item isKindOfClass:[NSDictionary class]]){
                                Class cls = propertyMeta.class;
                                if (propertyMeta.hasCustomClassFromDictionary) {
                                    cls = [cls gpModelCustomClassForDictionary:item];
                                    if(!cls) cls = propertyMeta.genericCls;
                                }
                                NSObject* newItem = [cls new];
                                [newItem gpModelSetWithDictionary:item];
                                if (newItem) [tmpSet addObject:newItem];
                            }
                        }
                        SETVALUE(id, model, propertyMeta.setter,
                                 (propertyMeta.nsType == GPEncodingNSTypeNSSet)? [tmpSet copy] : tmpSet);
                    }else{
                        SETVALUE(id, model, propertyMeta.setter,
                                 (propertyMeta.nsType == GPEncodingNSTypeNSSet)? valueSet : [valueSet mutableCopy]);
                    }
                }
                    break;
                case GPEncodingNSTypeUnknown:
                    break;
            }
        }
    }else{
        BOOL isNull = (value == (id)kCFNull);
        switch (propertyMeta.type & GPEncodingTypeMask) {
            case GPEncodingTypeObject:{
                if (isNull) {
                    SETVALUE(id, model, propertyMeta.setter, nil);
                }else if([value isKindOfClass:propertyMeta.cls]){
                    SETVALUE(id, model, propertyMeta.setter, value);
                }else if([value isKindOfClass:[NSDictionary class]]){
                    NSObject* item = nil;
                    if (propertyMeta.getter) {
                        item = GETVALUE(id,model,propertyMeta.getter);
                    }
                    if (item) {
                        [item gpModelSetWithDictionary:value];
                    }else {
                        Class cls = propertyMeta.cls;
                        if (propertyMeta.hasCustomClassFromDictionary) {
                            cls = [cls gpModelCustomClassForDictionary:value];
                            if (!cls) cls = propertyMeta.genericCls;
                        }
                        if (cls) {
                            item = [cls new];
                            [item gpModelSetWithDictionary:value];
                            SETVALUE(id, model, propertyMeta.setter, item);
                        }else {
                            SETVALUE(id, model, propertyMeta.setter, value);
                        }
                    }
                }else{
                    SETVALUE(id, model, propertyMeta.setter, value);
                }
            }
                break;
            case GPEncodingTypeClass:{
                if (isNull) {
                    SETVALUE(Class, model, propertyMeta.setter, (Class)NULL);
                }else {
                    Class cls = nil;
                    if ([value isKindOfClass:[NSString class]]) {
                        cls = NSClassFromString(value);
                        if (cls) {
                            SETVALUE(Class, model, propertyMeta.setter, cls);
                        }
                    }else{
                        cls = object_getClass(value);//获取类型
                        if(cls){
                            if (class_isMetaClass(cls)) {
                                SETVALUE(Class, model, propertyMeta.setter, (Class)value);
                            }else {
                                SETVALUE(Class, model, propertyMeta.setter, cls);
                            }
                        }
                    }
                }
            }
                break;
            case GPEncodingTypeSEL:{
                if (isNull) {
                    SETVALUE(SEL, model, propertyMeta.setter, (SEL)NULL);
                }else if([value isKindOfClass:[NSString class]]){
                    SEL sel = NSSelectorFromString(value);
                    if (sel)SETVALUE(SEL, model, propertyMeta.setter, sel);
                }
            }
                break;
            case GPEncodingTypeBlock:{
                if (isNull) {
                    SETVALUE(void(^)(), model, propertyMeta.setter,(void(^)())NULL);
                }else {
                    SETVALUE(void(^)(), model, propertyMeta.setter, value);
                }
            }
                break;
            case GPEncodingTypeUnion:
            case GPEncodingTypeCArray:
            case GPEncodingTypeStruct:{
                if ([value isKindOfClass:[NSValue class]]) {
                    const char* valueType = ((NSValue *)value).objCType;
                    const char* metaType = propertyMeta.info.typeEncoding.UTF8String;
                    if (valueType && metaType && strcmp(valueType,metaType) == 0) {
                        [model setValue:value forKey:propertyMeta.name];
                    }
                }
            }
                break;
            case GPEncodingTypePointer:
            case GPEncodingTypeCString:{
                if (isNull) {
                    SETVALUE(void*, model, propertyMeta.setter, NULL);
                }else if ([value isKindOfClass:[NSValue class]]){
                    const char* valueType = ((NSValue*)value).objCType;
                    if (valueType && strcmp(valueType, "^v") == 0) {
                        SETVALUE(void*, model, propertyMeta.setter, ((NSValue*)value).pointerValue);
                    }
                }
            }
                break;
            default:
                break;
        }
    }
}

/**
 *  模型切换时的方便结构，
 */
typedef struct {
    void *modelMeta;    //  GPModelMeta.
    void *model;        //  id 模型
    void *dictionary;   //  json 数据
} GPModelContext;

/**
 *  设置模型中的数据，kvc.
 *  外部调用的model,modelMeta必须有强引用
 *  @param key     不能为nil,为NSString类型
 *  @param value   不能为nil.
 *  @param context 不能为nil.
 */
static void GPModelSetWithDictionary(const void* key,const void* value, void* context)
{
    GPModelContext* tmpContext = context;
    __unsafe_unretained p_GPModelMeta* modelMeta = (__bridge p_GPModelMeta*)tmpContext->modelMeta;
    __unsafe_unretained p_GPModelPropertyMeta* propertyMeta = [modelMeta.mapper objectForKey:(__bridge id)key];
    __unsafe_unretained id model = (__bridge id)(tmpContext->model);
    while (propertyMeta) {
        if (propertyMeta.setter) {
            GPModelSetValueForProperty(model, (__bridge __unsafe_unretained id)value, propertyMeta);
        }
        //同一个key指向多个对象.
        propertyMeta = propertyMeta.next;
    }
}

/**
 *  根据属性元数据来设置模型的属性
 *
 *  @param _propertyMeta 元数据
 *  @param context      数据
 */
static void GPModelSetWithPropertyMetaArray(const void* _propertyMeta,void* context)
{
    GPModelContext* tmpContext = context;
    __unsafe_unretained NSDictionary* dic = (__bridge NSDictionary*)tmpContext->dictionary;
    __unsafe_unretained p_GPModelPropertyMeta* propertyMeta = (__bridge p_GPModelPropertyMeta*)_propertyMeta;
    if (!propertyMeta.setter) return;
    id value = nil;
    if (propertyMeta.mappedToKeyArray) {
        value = GPValueForMultiKeys(dic, propertyMeta.mappedToKeyArray);
    }else if(propertyMeta.mappedToKeyPath){
        value = GPValueForKeyPath(dic, propertyMeta.mappedToKeyPath);
    }else {
        value = dic[propertyMeta.mappedToKey];
    }
    if (value) {
        __unsafe_unretained id model = (__bridge id)tmpContext->model;
        GPModelSetValueForProperty(model, value, propertyMeta);
    }
}

/**
 *  返回一个有效的json数据,NSArray,NSDictionary,NSString,NSNumber,NSNull.如果有错误发生，则返回nil.
 *
 *  @param model 模型
 *
 *  @return 一个json对象
 */
static id GPModelToJSONObject(id model)
{
    if (!model || model == (id)kCFNull) return model;
    if ([model isKindOfClass:[NSString class]]) return model;
    if ([model isKindOfClass:[NSNumber class]]) return model;
    if ([model isKindOfClass:[NSDictionary class]]) {
        if ([NSJSONSerialization isValidJSONObject:model]) return model;
        NSMutableDictionary* newDic = [NSMutableDictionary new];
        [((NSDictionary *)model) enumerateKeysAndObjectsUsingBlock:^(NSString* key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            NSString* stringKey = [key isKindOfClass:[NSString class]] ? key : key.description;
            if (!stringKey) return ;
            id jsonObj = GPModelToJSONObject(obj);
            if (!jsonObj) jsonObj = (id)kCFNull;
            newDic[stringKey] = jsonObj;
        }];
        return newDic;
    }
    if ([model isKindOfClass:[NSSet class]]) {
        NSArray* array = ((NSSet*)model).allObjects;
        if ([NSJSONSerialization isValidJSONObject:array]) return array;
        NSMutableArray* newArray = [NSMutableArray new];
        for (id item in  array) {
            id jsonObj = GPModelToJSONObject(item);
            if (jsonObj && jsonObj != (id)kCFNull) {
                [newArray addObject:jsonObj];
            }
        }
        return newArray;
    }
    if ([model isKindOfClass:[NSArray class]]) {
        if ([NSJSONSerialization isValidJSONObject:model]) return model;
        NSMutableArray* newArray = [NSMutableArray new];
        for (id item in (NSArray*)model) {
            id jsonObj = GPModelToJSONObject(item);
            if (jsonObj && jsonObj != (id)kCFNull) {
                [newArray addObject:jsonObj];
            }
        }
        return newArray;
    }
    if ([model isKindOfClass:[NSURL class]]) return ((NSURL*)model).absoluteString;
    if ([model isKindOfClass:[NSAttributedString class]]) return ((NSAttributedString *)model).string;
    if ([model isKindOfClass:[NSDate class]]) return GPISODateString(model);
    if ([model isKindOfClass:[NSData class]]) return [[NSString alloc] initWithData:model encoding:NSUTF8StringEncoding];
    
    p_GPModelMeta* modelMeta = [p_GPModelMeta metaWithClass:[model class]];
    if (!modelMeta || modelMeta.keyMappedCount == 0) return nil;
    NSMutableDictionary* result = [NSMutableDictionary new];
    [modelMeta.mapper enumerateKeysAndObjectsUsingBlock:^(NSString* key, p_GPModelPropertyMeta* propertyMeta, BOOL * _Nonnull stop) {
        if (!propertyMeta.getter) return ;
        id value = nil;
        if (propertyMeta.isCNumber) {
            value = GPModelGenerateNSNumberFromProperty(model, propertyMeta);
        }else if(propertyMeta.nsType){
            id tmpValue = GETVALUE(id, model, propertyMeta.getter);
            value = GPModelToJSONObject(tmpValue);
        }else{
            switch (propertyMeta.type & GPEncodingTypeMask) {
                case GPEncodingTypeObject:{
                    id tmpValue = GETVALUE(id, model, propertyMeta.getter);
                    value = GPModelToJSONObject(tmpValue);
                    if (value == (id)kCFNull) value = nil;
                }
                    break;
                case GPEncodingTypeClass:{
                    Class v = GETVALUE(Class, model, propertyMeta.getter);
                    value = v ? NSStringFromClass(v) : nil;
                }
                    break;
                case GPEncodingTypeSEL:{
                    SEL v = GETVALUE(SEL, model, propertyMeta.getter);
                    value = v ? NSStringFromSelector(v) : nil;
                }
                    break;
                default:
                    break;
            }
        }
        if (!value) return;
        if (propertyMeta.mappedToKeyPath) {
            NSMutableDictionary* superDic = result;
            NSMutableDictionary* subDic = nil;
            for (NSUInteger idx = 0, max = propertyMeta.mappedToKeyPath.count;idx < max; ++idx) {
                NSString* key = propertyMeta.mappedToKeyPath[idx];
                if (idx + 1 == max) {
                    if (!superDic[key]) superDic[key] = value;
                    break;
                }
                
                subDic = superDic[key];
                if (subDic) {
                    if ([subDic isKindOfClass:[NSDictionary class]]) {
                        subDic = subDic.mutableCopy;
                        superDic[key] = subDic;
                    }else {
                        break;
                    }
                }else {
                    subDic = [NSMutableDictionary new];
                    superDic[key] = subDic;
                }
                superDic = subDic;
                subDic = nil;
            }
        }else {
            if (!result[propertyMeta.mappedToKey]) {
                result[propertyMeta.mappedToKey] = value;
            }
        }
    }];
    return result;
}

@implementation NSObject (GPModel)

#pragma mark - 共有方法
+ (instancetype)gpModelWithJSON:(id)json
{
    NSDictionary* dic = [self p_GPDictionaryWithJSON:json];
    return [self gpModelWithDictionary:dic];
}

+ (instancetype)gpModelWithDictionary:(NSDictionary *)jsonDic
{
    if (!jsonDic || jsonDic == (id)kCFNull) return nil;
    if (![jsonDic isKindOfClass:[NSDictionary class]]) return nil;
    Class cls = [self class];//获取自己的类型信息
    p_GPModelMeta* modelMeta = [p_GPModelMeta metaWithClass:cls];
    if (modelMeta.hasCustomClassFromDictionary) {
        cls = [cls gpModelCustomClassForDictionary:jsonDic];
    }
    NSObject* item = [cls new];
    if ([item gpModelSetWithDictionary:jsonDic]) return item;
    return nil;
}

+ (NSArray *)gpModelListWithJSON:(id)json
{
    return [NSArray gpModelArrayWithClass:self.class JSON:json];
}

+ (NSDictionary *)gpModelDictionaryWithJson:(id)json
{
    return [NSDictionary gpModelDictonryWithClass:self.class JSON:json];
}

- (BOOL)gpModelSetWithJSON:(id)json
{
    NSDictionary* dic = [NSObject p_GPDictionaryWithJSON:json];
    return [self gpModelSetWithDictionary:dic];
}

- (BOOL)gpModelSetWithDictionary:(NSDictionary *)jsonDic
{
    if (!jsonDic || jsonDic == (id)kCFNull) return NO;
    if (![jsonDic isKindOfClass:[NSDictionary class]]) return NO;
    Class cls = object_getClass(self);
    p_GPModelMeta* modelMeta = [p_GPModelMeta metaWithClass:cls];
    if (modelMeta.keyMappedCount == 0) return NO;
    GPModelContext context = {0};
    context.modelMeta = (__bridge void *)modelMeta;
    context.model = (__bridge void*)self;
    context.dictionary = (__bridge void*)jsonDic;
    
    if (modelMeta.keyMappedCount >= CFDictionaryGetCount((CFDictionaryRef)jsonDic)) {
        CFDictionaryApplyFunction((CFDictionaryRef)jsonDic, GPModelSetWithDictionary, &context);
        if (modelMeta.keyPathPropertyMetas) {
            CFArrayApplyFunction((CFArrayRef)modelMeta.keyPathPropertyMetas, CFRangeMake(0, CFArrayGetCount((CFArrayRef)modelMeta.keyPathPropertyMetas)), GPModelSetWithPropertyMetaArray, &context);
        }
        
        if (modelMeta.multiKeysPropertyMetas) {
            CFArrayApplyFunction((CFArrayRef)modelMeta.multiKeysPropertyMetas, CFRangeMake(0, CFArrayGetCount((CFArrayRef)modelMeta.multiKeysPropertyMetas)), GPModelSetWithPropertyMetaArray, &context);
        }
    }else {
        CFArrayApplyFunction((CFArrayRef)modelMeta.allPropertyMetas, CFRangeMake(0, modelMeta.keyMappedCount), GPModelSetWithPropertyMetaArray, &context);
    }
    
    return YES;
}

- (id)gpModelToJSONObject
{
    /*
     Apple said:
     The top level object is an NSArray or NSDictionary.
     All objects are instances of NSString, NSNumber, NSArray, NSDictionary, or NSNull.
     All dictionary keys are instances of NSString.
     Numbers are not NaN or infinity.
     */
    id jsonObject = GPModelToJSONObject(self);
    if ([jsonObject isKindOfClass:[NSArray class]])return jsonObject;
    if ([jsonObject isKindOfClass:[NSDictionary class]]) return jsonObject;
    if ([jsonObject isKindOfClass:[NSString class]]) return jsonObject;
    if ([jsonObject isKindOfClass:[NSNumber class]]) return jsonObject;
    return nil;
}

- (NSData *)gpModelToJSONData
{
    id jsonData = [self gpModelToJSONObject];
    if (!jsonData) return nil;
    return [NSJSONSerialization dataWithJSONObject:jsonData options:kNilOptions error:NULL];
}

- (NSString *)gpModelToJSONString
{
    NSData* jsonData = [self gpModelToJSONData];
    if (jsonData.length == 0) return nil;
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

/**
 *  拷贝
 *
 *  @return 返回gpModel对象
 */
- (id)gpModelCopy
{
    if (self == (id)kCFNull) return self;
    p_GPModelMeta* modelMeta = [p_GPModelMeta metaWithClass:self.class];
    if (modelMeta.nsType) return [self copy];
    NSObject* one = [self.class new];
    for (p_GPModelPropertyMeta* propertyMeta in  modelMeta.allPropertyMetas) {
        if (!propertyMeta.getter || !propertyMeta.setter) continue;
        if (propertyMeta.isCNumber) {
            switch (propertyMeta.type & GPEncodingTypeMask) {
                case GPEncodingTypeBool:{
                    bool num = GETVALUE(bool, self, propertyMeta.getter);
                    SETVALUE(bool, one, propertyMeta.setter, num);
                }
                    break;
                case GPEncodingTypeInt8:{
                    int8_t num = GETVALUE(int8_t, self, propertyMeta.getter);
                    SETVALUE(int8_t, one, propertyMeta.setter, num);
                }
                    break;
                case GPEncodingTypeUInt8:{
                    uint8_t num = GETVALUE(uint8_t, self, propertyMeta.getter);
                    SETVALUE(uint8_t, one, propertyMeta.setter, num);
                }
                    break;
                case GPEncodingTypeInt16:{
                    int16_t num = GETVALUE(int16_t, self, propertyMeta.getter);
                    SETVALUE(int16_t, one, propertyMeta.setter,num);
                }
                    break;
                case GPEncodingTypeUInt16:{
                    uint16_t num = GETVALUE(uint16_t, self, propertyMeta.getter);
                    SETVALUE(uint16_t, one, propertyMeta.setter, num);
                }
                    break;
                case GPEncodingTypeInt32:{
                    int32_t num = GETVALUE(int32_t, self, propertyMeta.getter);
                    SETVALUE(int32_t, one, propertyMeta.setter, num);
                }
                    break;
                case GPEncodingTypeUInt32:{
                    uint32_t num = GETVALUE(uint32_t, self, propertyMeta.getter);
                    SETVALUE(uint32_t, one, propertyMeta.setter, num);
                }
                    break;
                case GPEncodingTypeInt64:{
                    int64_t num = GETVALUE(int64_t, self, propertyMeta.getter);
                    SETVALUE(int64_t, one, propertyMeta.setter,num);
                }
                    break;
                case GPEncodingTypeUInt64:{
                    uint64_t num = GETVALUE(uint64_t, self, propertyMeta.getter);
                    SETVALUE(uint64_t, one, propertyMeta.setter, num);
                }
                    break;
                case GPEncodingTypeFloat:{
                    float num = GETVALUE(float, self, propertyMeta.getter);
                    if (isnan(num) || isinf(num)) num = 0;
                    SETVALUE(float, self, propertyMeta.setter, num);
                }
                    break;
                case GPEncodingTypeDouble:{
                    double num = GETVALUE(double, self, propertyMeta.getter);
                    if (isnan(num) || isinf(num)) num = 0;
                    SETVALUE(double, self, propertyMeta.setter, num);
                }
                    break;
                case GPEncodingTypeLongDouble:{
                    long double num = GETVALUE(long double, self, propertyMeta.getter);
                    if (isnan(num) || isinf(num)) num = 0;
                    SETVALUE(long double, self, propertyMeta.setter, num);
                }
                    break;
            }
        }else{
            switch (propertyMeta.type & GPEncodingTypeMask) {
                case GPEncodingTypeObject:
                case GPEncodingTypeClass:
                case GPEncodingTypeBlock:{
                    id value = GETVALUE(id, self, propertyMeta.getter);
                    SETVALUE(id, one, propertyMeta.setter, value);
                }
                    break;
                case GPEncodingTypeSEL:
                case GPEncodingTypePointer:
                case GPEncodingTypeCString:{
                    size_t value = GETVALUE(size_t, self, propertyMeta.getter);
                    SETVALUE(size_t, one, propertyMeta.setter, value);
                }
                    break;
                case GPEncodingTypeStruct:
                case GPEncodingTypeUnion:{
                    NSValue* value = [self valueForKey:propertyMeta.name];
                    if (value) {
                        [one setValue:value forKey:propertyMeta.name];
                    }
                }
                    break;
                default:
                    break;
            }
        }
    }
    return one;
}

- (void)gpModelEncodeWithCoder:(NSCoder *)aCoder
{
    if(!aCoder) return;
    if (self == (id)kCFNull) {
        [((id<NSCoding>)self) encodeWithCoder:aCoder];
        return;
    }
    
    p_GPModelMeta* modelMeta = [p_GPModelMeta metaWithClass:self.class];
    if (modelMeta.nsType) {
        [((id<NSCoding>)self) encodeWithCoder:aCoder];
        return;
    }
    
    for (p_GPModelPropertyMeta* propertyMeta in modelMeta.allPropertyMetas) {
        if (!propertyMeta.getter) return;
        if (propertyMeta.isCNumber) {
            NSNumber *value = GPModelGenerateNSNumberFromProperty(self, propertyMeta);
            if (value) [aCoder encodeObject:value forKey:propertyMeta.name];
        }else
        {
            switch (propertyMeta.type & GPEncodingTypeMask) {
                case GPEncodingTypeObject:{
                    id value = GETVALUE(id, self, propertyMeta.getter);
                    if (value && (propertyMeta.nsType || [value respondsToSelector:@selector(encodeWithCoder:)])) {
                        [aCoder encodeObject:value forKey:propertyMeta.name];
                    }
                }
                    break;
                case GPEncodingTypeSEL:{
                    SEL value = GETVALUE(SEL, self, propertyMeta.getter);
                    if (value) {
                        NSString* str = NSStringFromSelector(value);
                        [aCoder encodeObject:str forKey:propertyMeta.name];
                    }
                }
                    break;
                case GPEncodingTypeStruct:
                case GPEncodingTypeUnion:{
                    if (propertyMeta.isKvcCompatible && propertyMeta.isStructAvailableForKeyedArchiver) {
                        NSValue* value = [self valueForKey:NSStringFromSelector(propertyMeta.getter)];
                        if (value) {
                            [aCoder encodeObject:value forKey:propertyMeta.name];
                        }
                    }
                }
                default:
                    break;
            }
        }
    }
}

- (id)gpModelInitWithCoder:(NSCoder *)aCoder
{
    if (!aCoder) return nil;
    if (self == (id)kCFNull) return self;
    p_GPModelMeta* modelMeta = [p_GPModelMeta metaWithClass:self.class];
    if (modelMeta.nsType) return self;
    for (p_GPModelPropertyMeta* propertyMeta in modelMeta.allPropertyMetas) {
        if (!propertyMeta.setter) continue;
        if (propertyMeta.isCNumber) {
            NSNumber* value = [aCoder decodeObjectForKey:propertyMeta.name];
            if ([value isKindOfClass:[NSNumber class]]) {
                GPModelSetCNumberToProperty(self, value, propertyMeta);
            }
        }else {
            switch (propertyMeta.type & GPEncodingTypeMask) {
                case GPEncodingTypeObject:{
                    id value = [aCoder decodeObjectForKey:propertyMeta.name];
                    SETVALUE(id, self, propertyMeta.setter, value);
                }
                    break;
                case GPEncodingTypeSEL:{
                    NSString* selString = [aCoder decodeObjectForKey:propertyMeta.name];
                    if ([selString isKindOfClass:[NSString class]]) {
                        SEL sel = NSSelectorFromString(selString);
                        SETVALUE(SEL, self,propertyMeta.setter , sel);
                    }
                }
                    break;
                case GPEncodingTypeStruct:
                case GPEncodingTypeUnion:{
                    if (propertyMeta.isKvcCompatible) {
                        NSValue* value = [aCoder decodeObjectForKey:propertyMeta.name];
                        if (value) {
                            [self setValue:value forKey:propertyMeta.name];
                        }
                    }
                }
                    break;
                default:
                    break;
            }
        }
    }
    return self;
}

- (NSUInteger)gpModelHash
{
    if (self == (id)kCFNull) return [self hash];
    p_GPModelMeta* modelMeta = [p_GPModelMeta metaWithClass:self.class];
    if (modelMeta.nsType) return [self hash];
    
    NSUInteger value = 0;
    NSUInteger count = 0;
    for (p_GPModelPropertyMeta* propertyMeta in  modelMeta.allPropertyMetas) {
        if (!propertyMeta.isKvcCompatible) continue;
        value ^= [[self valueForKey:NSStringFromSelector(propertyMeta.getter)] hash];
        count ++;
    }
    if (count == 0) value = (NSUInteger)(__bridge void *)self;
    return value;
}

- (BOOL)gpModelIsEqual:(id)model
{
    if (self == model) return YES;
    if (![model isMemberOfClass:self.class]) return NO;
    p_GPModelMeta* modelMeta = [p_GPModelMeta metaWithClass:self.class];
    if (modelMeta.nsType) return [self isEqual:model];
    if ([self hash] != [model hash]) return NO;
    
    for (p_GPModelPropertyMeta* propertyMeta in modelMeta.allPropertyMetas) {
        if (!propertyMeta.isKvcCompatible) continue;
        id this = [self valueForKey:NSStringFromSelector(propertyMeta.getter)];
        id that = [model valueForKey:NSStringFromSelector(propertyMeta.getter)];
        if (this == that) continue;
        if (this == nil || that == nil) return NO;
        if ([this isEqual:that]) continue;
    }
    return YES;
}


#pragma mark - 私有方法
/**
 *  将json对象转换成NSDictionary.
 *
 *  @param json 可为NSStrin,NSData,NSDictionry.
 *
 *  @return 字典对象
 */
+ (NSDictionary *)p_GPDictionaryWithJSON:(id)json
{
    if (!json || json == (id)kCFNull) return nil;
    NSDictionary* dic = nil;
    NSData* jsonData = nil;
    if ([json isKindOfClass:[NSDictionary class]]) {
        dic = json;
    }else if([json isKindOfClass:[NSString class]]){
        jsonData = [(NSString *)json dataUsingEncoding:NSUTF8StringEncoding];
    }else if([json isKindOfClass:[NSData class]]){
        jsonData = json;
    }
    
    if (jsonData) {
        dic = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:NULL];
        if (![dic isKindOfClass:[NSDictionary class]]) return  nil;
    }
    return dic;
}
@end

@implementation NSArray (GPModel)

+ (NSArray *)gpModelArrayWithClass:(Class)cls JSON:(id)json
{
    if (!json) return nil;
    NSArray* arr = nil;
    NSData* jsonData = nil;
    if ([json isKindOfClass:[NSArray class]]) {
        arr = json;
    }else if([json isKindOfClass:[NSString class]]){
        jsonData = [(NSString *)json dataUsingEncoding:NSUTF8StringEncoding];
    }else if([json isKindOfClass:[NSData class]]){
        jsonData = json;
    }
    
    if (jsonData) {
        arr = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:NULL];
        if ([arr isKindOfClass:[NSArray class]]) arr = nil;
    }
    
    return [self p_GPModelArrayWithClass:cls array:arr];
}

+ (NSArray *)p_GPModelArrayWithClass:(Class)cls array:(NSArray *)array
{
    if(!cls || !array) return nil;
    NSMutableArray* result = [NSMutableArray new];
    for (NSDictionary *dic in  array) {
        if (![dic isKindOfClass:[NSDictionary class]]) continue;
        NSObject* obj = [cls gpModelWithDictionary:dic];
        if (obj) [result addObject:obj];
    }
    return [result copy];
}

@end

@implementation NSDictionary(GPModel)

+ (NSDictionary *)gpModelDictonryWithClass:(Class)cls JSON:(id)json
{
    if (!json) return nil;
    NSDictionary* dic = nil;
    NSData* jsonData = nil;
    if ([json isKindOfClass:[NSDictionary class]]) {
        dic = json;
    }else if([json isKindOfClass:[NSString class]]){
        jsonData = [(NSString *)json dataUsingEncoding:NSUTF8StringEncoding];
    }else if([json isKindOfClass:[NSData class]]){
        jsonData = json;
    }
    
    if (jsonData) {
        dic = [NSJSONSerialization JSONObjectWithData:json options:kNilOptions error:NULL];
        if (![dic isKindOfClass:[NSDictionary class]]) dic = nil;
    }
    
    return [self p_GPModelDictionaryWithClass:cls dictionary:dic];
}

+ (NSDictionary *)p_GPModelDictionaryWithClass:(Class)cls dictionary:(NSDictionary *)dic
{
    if (!cls || !dic) return nil;
    NSMutableDictionary* resultDic = [NSMutableDictionary new];
    for (NSString *key in  dic.allKeys) {
        if (![key isKindOfClass:[NSString class]]) continue;
        NSObject* obj = [cls gpModelWithDictionary:dic[key]];
        if (obj) resultDic[key] = obj;
    }
    return [resultDic copy];
}

@end
