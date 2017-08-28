//
//  GPModelClassInfo.m
//  GPModel
//
//  Created by feng on 15/12/27.
//  Copyright © 2015年 feng. All rights reserved.
//

#import "GPModelClassInfo.h"
#import <libkern/OSAtomic.h>

#pragma mark - GetEncodingType
GPEncodingType GetEncodingType(const char* typeEncoding)
{
    char* type = (char*) typeEncoding;
    //判空
    if (!type) return GPEncodingTypeUnknown;
    //获取字符串长度
    size_t length = strlen(type);
    //判空
    if (length == 0) return GPEncodingTypeUnknown;
    
    //获取前缀
    GPEncodingType qualifier = 0;
    BOOL prefix = true;
    while (prefix) {
        switch (*type) {
            case 'r':
            {
                qualifier |= GPEncodingTypeQualifierConst;
                type ++;
            }
                break;
            case 'n':
            {
                qualifier |= GPEncodingTypeQualifierIn;
                type ++;
            }
                break;
            case 'N':
            {
                qualifier |= GPEncodingTypeQualifierInout;
                type ++;
            }
                break;
            case 'o':
            {
                qualifier |= GPEncodingTypeQualifierOut;
                type ++;
            }
                break;
            case 'O':
            {
                qualifier |= GPEncodingTypeQualifierBycopy;
                type ++;
            }
                break;
            case 'R':
            {
                qualifier |= GPEncodingTypeQualifierByref;
                type ++;
            }
                break;
            case 'V':
            {
                qualifier |= GPEncodingTypeQualifierOneway;
                type ++;
            }
                break;
            default:
            {
                prefix = false;
            }
                break;
        }
    }
    //获取剩下的字符串长度
    length = strlen(type);
    if (length == 0) return  qualifier;
    
    switch (*type) {
        case 'v':return GPEncodingTypeVoid | qualifier;
        case 'B':return GPEncodingTypeBool | qualifier;
        case 'c':return GPEncodingTypeInt8 | qualifier;
        case 'C':return GPEncodingTypeUInt8 | qualifier;
        case 's':return GPEncodingTypeInt16 | qualifier;
        case 'S':return GPEncodingTypeUInt16 | qualifier;
        case 'i':return GPEncodingTypeInt32 | qualifier;
        case 'I':return GPEncodingTypeUInt32 | qualifier;
        case 'l':return GPEncodingTypeInt64 | qualifier;
        case 'L':return GPEncodingTypeUInt64 | qualifier;
        case 'q':return GPEncodingTypeInt64 | qualifier;
        case 'Q':return GPEncodingTypeUInt64 | qualifier;
        case 'f':return GPEncodingTypeFloat | qualifier;
        case 'd':return GPEncodingTypeDouble | qualifier;
        case 'D':return GPEncodingTypeLongDouble | qualifier;
        case '#':return GPEncodingTypeClass | qualifier;
        case ':':return GPEncodingTypeSEL | qualifier;
        case '*':return GPEncodingTypeCString | qualifier;
        case '^':return GPEncodingTypePointer | qualifier;
        case '[':return GPEncodingTypeCArray  | qualifier;
        case '(':return GPEncodingTypeUnion | qualifier;
        case '{':return GPEncodingTypeStruct | qualifier;
        case '@':{
            if (length == 2 && *(type + 1) == '?') {
                return GPEncodingTypeBlock | qualifier;
            }else
            {
                return GPEncodingTypeObject | qualifier;
            }
        }
        default:
            return GPEncodingTypeUnknown | qualifier;
    }
    
}

#pragma mark - GPClassIvarInfo

@implementation GPClassIvarInfo

- (instancetype)initWithIvar:(Ivar)ivar
{
    //判空，如果为空指针，返回nil
    if (!ivar) return nil;
    self = [super init];
    if (self) {
        _ivar = ivar;
        //获取变量名
        const char* name = ivar_getName(ivar);
        if (name) {
            _name = [NSString stringWithUTF8String:name];
        }
        //变量偏移
        _offset = ivar_getOffset(ivar);
        //获取变量类型编码
        const char* typeEncoding = ivar_getTypeEncoding(ivar);
        if (typeEncoding) {
            _typeEncoding = [NSString stringWithUTF8String:typeEncoding];
            _type = GetEncodingType(typeEncoding);
        }
    }
    return self;
}

@end

#pragma mark - GPClassMethodInfo

@implementation GPClassMethodInfo

- (instancetype)initWithMethod:(Method)method
{
    if (!method) return nil;
    self = [super init];
    if (self) {
        _method = method;
        //选择子名字
        _sel = method_getName(method);
        //方法实现
        _imp = method_getImplementation(method);
        //将选择名字转化为string
        const char* name = sel_getName(_sel);
        if(name){
            _name = [NSString stringWithUTF8String:name];
        }
        //方法编码
        const char* typeEncoding = method_getTypeEncoding(method);
        if (typeEncoding) {
            _typeEncoding = [NSString stringWithUTF8String:typeEncoding];
        }
        //返回编码
        char* returnType = method_copyReturnType(method);
        if (returnType) {
            _returnTypeEncoding = [NSString stringWithUTF8String:returnType];
            free(returnType);
        }
        //方法参数数量
        unsigned int argumentCount = method_getNumberOfArguments(method);
        if (argumentCount > 0) {
            NSMutableArray* argumentTypes = [NSMutableArray new];
            //获取方法参数类型
            for (unsigned int idx = 0; idx < argumentCount; ++idx) {
                char* argumentType = method_copyArgumentType(method, idx);
                if (argumentType) {
                    NSString* type = [NSString stringWithUTF8String:argumentType];
                    [argumentTypes addObject:type];
                    free(argumentType);
                }
            }
            _argumentTypeEncodings = argumentTypes;
        }
    }
    return self;
}

@end

#pragma mark - GPClassPropertyInfo

@implementation GPClassPropertyInfo

- (instancetype)initWithProperty:(objc_property_t)property
{
    if (!property) return nil;
    self = [super init];
    if (self) {
        //runtime的属性类型
        _property = property;
        //属性名字
        const char* name = property_getName(property);
        if (name) {
            _name = [NSString stringWithUTF8String:name];
        }
        
        GPEncodingType type = GPEncodingTypeUnknown;
        unsigned int attrCount;
        objc_property_attribute_t* attrs = property_copyAttributeList(property, &attrCount);
        //遍历property 的属性，
        for (unsigned int idx = 0; idx < attrCount; ++idx) {
            switch (attrs[idx].name[0]) {
                case 'T': //  type encoding
                    if (attrs[idx].value) {
                        _typeEncoding = [NSString stringWithUTF8String:attrs[idx].value];
                        type = GetEncodingType(attrs[idx].value);
                        if (type & GPEncodingTypeObject) {
                            size_t len = strlen(attrs[idx].value);
                            if (len > 3) {
                                char name[len - 2];
                                name[len - 3] = '\0';
                                memcpy(name, attrs[idx].value + 2, len - 3);
                                _cls = objc_getClass(name);
                            }
                        }
                    }
                    break;
                case 'V':{ //  instance var
                    if (attrs[idx].value) {
                        _ivarName = [NSString stringWithUTF8String:attrs[idx].value];
                    }
                }
                    break;
                case 'R':
                    type |= GPEncodingTypePropertyReadonly;
                    break;
                case 'C':
                    type |= GPEncodingTypePropertyCopy;
                    break;
                case '&':
                    type |= GPEncodingTypePropertyRetain;
                    break;
                case 'N':
                    type |= GPEncodingTypePropertyNonatomic;
                    break;
                case 'D':
                    type |= GPEncodingTypePropertyDynamic;
                    break;
                case 'W':
                    type |= GPEncodingTypePropertyWeak;
                    break;
                case 'G':{
                    type |= GPEncodingTypePropertyGetter;
                    if (attrs[idx].value) {
                        _getter = [NSString stringWithUTF8String:attrs[idx].value];
                    }
                }
                    break;
                case 'S':{
                    type |= GPEncodingTypePropertySetter;
                    if (attrs[idx].value) {
                        _setter = [NSString stringWithUTF8String:attrs[idx].value];
                    }
                }
                default:
                    break;
            }
        }
        
        if (attrs) {
            free(attrs);
            attrs = NULL;
        }
        
        _type = type;
        if (_name.length) {
            if (!_getter) {
                _getter = _name;
            }
            if (!_setter) {
                _setter = [NSString stringWithFormat:@"set%@%@:",[_name substringToIndex:1].uppercaseString,[_name substringFromIndex:1]];
            }
        }
    }
    return self;
}

@end

#pragma mark - GPModelClassInfo
@implementation GPModelClassInfo
{
    BOOL _needUpdate;
}

#pragma mark - life
- (instancetype)initWithClass:(Class)cls
{
    if (!cls) return nil;
    self = [super init];
    if (self) {
        _cls = cls;
        _superCls = class_getSuperclass(cls);
        _isMetaClass = class_isMetaClass(cls);
        if (!_isMetaClass) {
            _metaCls = objc_getMetaClass(class_getName(cls));
        }
        _name = NSStringFromClass(cls);
        [self p_update];
        _superClassInfo = [self.class classInfoWithClass:_superCls];
    }
    return self;
}

#pragma mark - pubulic methods
- (void)setNeedUpdate
{
    _needUpdate = YES;
}

+ (instancetype)classInfoWithClass:(Class)cls
{
    if (!cls) return nil;
    static CFMutableDictionaryRef classCache;
    static CFMutableDictionaryRef metaCache;
    static dispatch_once_t once;
    static OSSpinLock lock;
    dispatch_once(&once , ^{
        lock = OS_SPINLOCK_INIT; //initialize thread lock
        classCache = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        metaCache = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    });
    OSSpinLockLock(&lock); //lock
    GPModelClassInfo* info = CFDictionaryGetValue(class_isMetaClass(cls) ? metaCache : classCache, (__bridge const void *)(cls));
    if (info && info->_needUpdate) {
        [info p_update];
    }
    OSSpinLockUnlock(&lock); //unlock
    if (!info) {
        info = [[GPModelClassInfo alloc] initWithClass:cls];
        if (info) {
            OSSpinLockLock(&lock);
            CFDictionarySetValue(class_isMetaClass(cls) ? metaCache : classCache, (__bridge const void *)cls, (__bridge const void*)info);
            OSSpinLockUnlock(&lock);
        }
    }
    return info;
}

+ (instancetype)classInfoWithClassName:(NSString *)className
{
    Class cls = NSClassFromString(className);
    return [self classInfoWithClass:cls];
}

#pragma mark - private methods
/**
 *  update class info .about method,var,property.
 */
- (void)p_update
{
    _ivarInfos = nil;
    _methodInfos = nil;
    _propertyInfos = nil;
    
    Class cls = _cls;
    //方法
    unsigned int methodCount = 0;
    Method* methods = class_copyMethodList(cls, &methodCount);
    if (methods) {
        NSMutableDictionary* methodInfos = [NSMutableDictionary new];
        for (unsigned int idx = 0; idx < methodCount; ++idx) {
            GPClassMethodInfo* info = [[GPClassMethodInfo alloc] initWithMethod:methods[idx]];
            if (info.name) {
                methodInfos[info.name] = info;
            }
        }
        _methodInfos = methodInfos;
        free(methods);
    }
    //属性
    unsigned int propertyCount = 0;
    objc_property_t* propertyies = class_copyPropertyList(cls, &propertyCount);
    if (propertyies) {
        NSMutableDictionary* propertyInfos = [NSMutableDictionary new];
        for (unsigned int idx = 0;idx < propertyCount; ++idx) {
            GPClassPropertyInfo* propertyInfo = [[GPClassPropertyInfo alloc] initWithProperty:propertyies[idx]];
            if (propertyInfo.name) {
                propertyInfos[propertyInfo.name] = propertyInfo;
            }
        }
        _propertyInfos = propertyInfos;
        free(propertyies);
    }
    //实例变量
    unsigned int ivarCount = 0;
    Ivar* ivars = class_copyIvarList(cls, &ivarCount);
    if (ivars) {
        NSMutableDictionary* ivarInfos = [NSMutableDictionary new];
        for (unsigned int idx = 0; idx < ivarCount; ++idx) {
            GPClassIvarInfo* ivarInfo = [[GPClassIvarInfo alloc] initWithIvar:ivars[idx]];
            if (ivarInfo.name) {
                ivarInfos[ivarInfo.name] = ivarInfo;
            }
        }
        _ivarInfos = ivarInfos;
        free(ivars);
    }
    _needUpdate = NO;
}


@end
