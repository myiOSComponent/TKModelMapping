//
//  GPModelClassInfo.h
//  GPModel
//
//  Created by feng on 15/12/27.
//  Copyright © 2015年 feng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

/**
 *  编码类型
 */
typedef NS_OPTIONS(NSUInteger, GPEncodingType) {
    GPEncodingTypeMask          = 0xFF, // 编码类型标志
    GPEncodingTypeUnknown       = 0,    // unknown
    GPEncodingTypeVoid          = 1,    // Void
    GPEncodingTypeBool          = 2,    // bool
    GPEncodingTypeInt8          = 3,    // char/BOOL
    GPEncodingTypeUInt8         = 4,    // unsigned char
    GPEncodingTypeInt16         = 5,    // short
    GPEncodingTypeUInt16        = 6,    // unsigned short
    GPEncodingTypeInt32         = 7,    // int
    GPEncodingTypeUInt32        = 8,    // unsigned int
    GPEncodingTypeInt64         = 9,    // long long
    GPEncodingTypeUInt64        = 10,   // unsigned long long
    GPEncodingTypeFloat         = 11,   // float
    GPEncodingTypeDouble        = 12,   // double
    GPEncodingTypeLongDouble    = 13,   // long double
    GPEncodingTypeObject        = 14,   // object -> id
    GPEncodingTypeClass         = 15,   // Class
    GPEncodingTypeSEL           = 16,   // SEL
    GPEncodingTypeBlock         = 17,   // Block
    GPEncodingTypePointer       = 18,   // Pointer -> void*
    GPEncodingTypeStruct        = 19,   // struct
    GPEncodingTypeUnion         = 20,   // Union
    GPEncodingTypeCString       = 21,   // CString
    GPEncodingTypeCArray        = 22,   // char[10]
    
    GPEncodingTypeQualifierMask     = 0xFF00,   // 标志限定词
    GPEncodingTypeQualifierConst    = 1 << 8,   // const
    GPEncodingTypeQualifierIn       = 1 << 9,   // in
    GPEncodingTypeQualifierInout    = 1 << 10,  // inout
    GPEncodingTypeQualifierOut      = 1 << 11,  // out
    GPEncodingTypeQualifierBycopy   = 1 << 12,  // bycopy
    GPEncodingTypeQualifierByref    = 1 << 13,  // byref
    GPEncodingTypeQualifierOneway   = 1 << 14,  // oneway
    
    GPEncodingTypePropertyMask          = 0xFF0000, //属性限定词标志
    GPEncodingTypePropertyReadonly      = 1 << 16,  // readonly
    GPEncodingTypePropertyCopy          = 1 << 17,  // copy
    GPEncodingTypePropertyRetain        = 1 << 18,  // retain
    GPEncodingTypePropertyNonatomic     = 1 << 19,  // nonatomic
    GPEncodingTypePropertyWeak          = 1 << 20,  // weak
    GPEncodingTypePropertyGetter        = 1 << 21,  // getter=
    GPEncodingTypePropertySetter        = 1 << 22,  // setter=
    GPEncodingTypePropertyDynamic       = 1 << 23,  // dynamic
};

/**
 *  NSFoundationType
 */
typedef NS_ENUM(NSUInteger, GPEncodingNSType) {
    GPEncodingNSTypeUnknown = 0,                // unknown
    GPEncodingNSTypeNSString = 1,               // NSString.
    GPEncodingNSTypeNSMutableString = 2,        // NSMutableString.
    GPEncodingNSTypeNSValue = 3,                // NSValue.
    GPEncodingNSTypeNSNumber = 4,               // NSNumber.
    GPEncodingNSTypeNSDecimalNumber = 5,        // NSDecimalNumber.
    GPEncodingNSTypeNSData = 6,                 // NSData.
    GPEncodingNSTypeNSMutableData = 7,          // NSMutableData.
    GPEncodingNSTypeNSDate = 8,                 // NSDate.
    GPEncodingNSTypeNSURL = 9,                  // NSURL.
    GPEncodingNSTypeNSArray = 10,                // NSArray.
    GPEncodingNSTypeNSMutableArray = 11,        // NSMutableArray.
    GPEncodingNSTypeNSDictionary = 12,          // NSDictionary.
    GPEncodingNSTypeNSMutableDictionary = 13,   // NSMutableDictionary.
    GPEncodingNSTypeNSSet = 14,                 // NSSet.
    GPEncodingNSTypeNSMutableSet = 15,          // NSMutableSet.
};

/**
 *  get the type form a typeEncoding string
 *
 *  @discussion: see some of typeString
 *  https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html
 *  https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtPropertyIntrospection.html
 *
 *
 *  @param typeEncoding a type-Encoding string
 *
 *  @return the encoding type
 */
FOUNDATION_EXTERN GPEncodingType GetEncodingType(const char* typeEncoding);

/**
 *  instance variable information
 */

@interface GPClassIvarInfo : NSObject

@property (nonatomic, assign, readonly) Ivar ivar;              // runtime的变量结构
@property (nonatomic, assign, readonly) ptrdiff_t offset;       // 编译器类型,变量的偏移
@property (nonatomic, assign, readonly) GPEncodingType type;    // 编码类型
@property (nonatomic, strong, readonly) NSString* name;         // 变量名
@property (nonatomic, strong, readonly) NSString* typeEncoding; // 编码

/**
 *  create an var info with an opaque struct.
 *
 *  @param ivar runtime Ivar opaque struct
 *
 *  @return ivar info object or nil if an error occurs.
 */
- (instancetype)initWithIvar:(Ivar)ivar;

@end

/**
 *  method info
 */
@interface GPClassMethodInfo : NSObject

@property (nonatomic, assign, readonly) Method method;              // runtime的函数类型
@property (nonatomic, assign, readonly) SEL sel;                    // 方法的选择子
@property (nonatomic, assign, readonly) IMP imp;                    // 方法实现
@property (nonatomic, strong, readonly) NSString* name;             // 方法名字
@property (nonatomic, strong, readonly) NSString* typeEncoding;     // 类型编码
@property (nonatomic, strong, readonly) NSString* returnTypeEncoding; // 返回类型编码
@property (nonatomic, strong, readonly) NSArray* argumentTypeEncodings; // 参数类型编码

/**
 *  create an method info object with an opaque struct.
 *
 *  @param method runtime method opaque struct
 *
 *  @return A new object, or nil if an error occurs.
 */
- (instancetype)initWithMethod:(Method)method;

@end

/**
 *  property info
 */
@interface GPClassPropertyInfo : NSObject

@property (nonatomic, assign, readonly) objc_property_t property; // runtime property struct
@property (nonatomic, assign, readonly) GPEncodingType type;      // property type
@property (nonatomic, assign, readonly) Class   cls;              // property class it may be nil
@property (nonatomic, strong, readonly) NSString* name;           // property name.
@property (nonatomic, strong, readonly) NSString* typeEncoding;   // property encoding.
@property (nonatomic, strong, readonly) NSString* ivarName;       // property ivar Name;
@property (nonatomic, strong, readonly) NSString* getter;         // getter.
@property (nonatomic, strong, readonly) NSString* setter;         // setter.

/**
 *  create an property info object with an opaque struct.
 *
 *  @return A new object,or nil if an error occurs.
 */
- (instancetype) initWithProperty:(objc_property_t)property;

@end

/**
 *  class informatioin.
 */
@interface GPModelClassInfo : NSObject

@property (nonatomic, assign, readonly) Class cls;          // class
@property (nonatomic, assign, readonly) Class superCls;     // superClass
@property (nonatomic, assign, readonly) Class metaCls;      // metaClass
@property (nonatomic, assign, readonly) BOOL isMetaClass;   // this class is metaClass.
@property (nonatomic, strong, readonly) NSString* name;     // class Name
@property (nonatomic, strong, readonly) GPModelClassInfo* superClassInfo; // super class info.
@property (nonatomic, strong, readonly) NSDictionary<NSString*,GPClassIvarInfo*>* ivarInfos; // var info key:ivar,value:GPClassIvarInfo.
@property (nonatomic, strong, readonly) NSDictionary<NSString*,GPClassMethodInfo*>* methodInfos; // method info. key:sel,value:GPClassMethodInfo.
@property (nonatomic, strong, readonly) NSDictionary<NSString*,GPClassPropertyInfo*>* propertyInfos; // property info.key:property,value:GPClassPropertyInfo.

/**
 *  if the class is changed,you should call this method to update class cache.
 *  for exp:you add a method wiht class_addMethod().
 *  after call this method,you may call classInfoWithClass to get new class info.
 */
- (void)setNeedUpdate;

/**
 *  get the class info
 *  the method will cache the class info and superClass info at the first access to the class.
 *  the method is thread safe.
 *  @param cls  class
 *
 *  @return A calss info , or nil if an error occurs.
 */
+ (instancetype)classInfoWithClass:(Class)cls;

/**
 *  get the class info
 *
 *  @param className class name
 *
 *  @return A class info,or nil if an error occurs.
 */
+ (instancetype)classInfoWithClassName:(NSString *)className;

@end
