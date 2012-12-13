//
//  QTKitDecrap.h
//  Subler
//
//  Created by Damiano Galassi on 13/12/12.
//  Duplicate and fix QTMetadataItem so it can be compiled while targetting 10.6.
//  Who knows the reason, it's so easy in Cocoa to check if a class exists at runtime...
//  Oh and almost all the constants from QTMetadataItem all broken, @ instead of ©.
//  Plus define a QTKit costant.

extern NSString * const QTTrackLanguageAttribute;	// NSNumber (long)

@interface QTMovie (QTMovie_MetadataReading_10_6_Fix)

#if (defined(MAC_OS_X_VERSION_10_7))
/*!
 @method			commonMetadata
 @abstract		Returns an NSArray containing QTMetadataItem objects for each common metadata key for which a value for the current locale is available.
 @result			An NSArray containing QTMetadataItem objects for each common metadata key for which a value for the current locale is available; may be nil if there is no metadata that's appropriately localized.
 @discussion		The returned metadata may be tagged with default locale information or with no locale information, if that's the best available choice.
 */
- (NSArray *)commonMetadata;

/*!
 @method			availableMetadataFormats
 @abstract		Returns an NSArray containing NSString objects representing the metadata formats available to the receiver.
 @result			An NSArray containing an NSString objects, each of which represents a metadata format that is available to the receiver.
 */
- (NSArray *)availableMetadataFormats;

/*!
 @method			metadataForFormat:
 @abstract		Returns an NSArray of QTMetadataItem objects having a specified format.
 @param			format
 The metadata format for which items are requested.
 @result			An NSArray containing all QTMetadataItem objects of the receiver that have the specified format; may be nil if there is no metadata of the specified format.
 */
- (NSArray *)metadataForFormat:(NSString *)format;
#endif

@end


#if (defined(MAC_OS_X_VERSION_10_7))
/*!
 @class			QTMetadataItem
 @abstract		QTMetadataItem represents an item of metadata associated with a QTMovie or QTTrack object.
 
 @discussion		QTMetadataItem objects have keys that accord with the specification of the container format from which they're drawn.
 
 You can filter arrays of QTMetadataItem objects by locale or by key and keyspace via the category
 QTMetadataItem_ArrayFiltering defined below.
 */

@class QTMetadataItemInternal;

@interface QTMetadataItem : NSObject <NSCopying, NSMutableCopying, NSCoding>
{
	QTMetadataItemInternal	*_priv;
}

/* indicates the key of the metadata item */
@property (readonly, copy) id<NSCopying> key;

/* indicates the keyspace of the metadata item's key; this will typically be the default keyspace for the metadata container in which the metadata item is stored */
@property (readonly, copy) NSString *keySpace;

/* indicates the locale of the metadata item; may be nil if no locale information is available for the metadata item */
@property (readonly, copy) NSLocale *locale;

/* indicates the timestamp of the metadata item. */
@property (readonly) QTTime time;

/* provides the value of the metadata item */
@property (readonly, copy) id<NSCopying> value;

/* provides a dictionary of the additional attributes */
@property (readonly, copy) NSDictionary *extraAttributes;

@end


@interface QTMetadataItem (QTMetadataItem_TypeCoercion)

/* provides the value of the metadata item as a string; will be nil if the value cannot be represented as a string */
@property (readonly) NSString *stringValue;

/* provides the value of the metadata item as an NSNumber. If the metadata item's value can't be coerced to a number, @"numberValue" will be nil. */
@property (readonly) NSNumber *numberValue;

/* provides the value of the metadata item as an NSDate. If the metadata item's value can't be coerced to a date, @"dateValue" will be nil. */
@property (readonly) NSDate *dateValue;

/* provides the raw bytes of the value of the metadata item */
@property (readonly) NSData *dataValue;

@end


@interface QTMetadataItem (QTMetadataItem_ArrayFiltering)

/*!
 @method			metadataItemsFromArray:withLocale:
 @abstract		Filters an array of QTMetadataItem objects according to locale.
 @param			array
 An array of QTMetadataItem objects to be filtered by locale.
 @param			locale
 The NSLocale that must be matched for a metadata item to be copied to the output array.
 @result			An NSArray object containing the metadata items of the specified NSArray that match the specified locale.
 */
+ (NSArray *)metadataItemsFromArray:(NSArray *)array withLocale:(NSLocale *)locale;

/*!
 @method			metadataItemsFromArray:withKey:keySpace:
 @abstract		Filters an array of QTMetadataItem objects according to key and/or keySpace.
 @param			array
 An array of QTMetadataItem objects to be filtered by key and/or keySpace.
 @param			key
 The key that must be matched for a metadata item to be copied to the output array.
 The keys will be compared to the keys of the QTMetadataItem objects in the array via [key isEqual:].
 If no filtering according to key is desired, pass nil.
 @param			keySpace
 The keySpace that must be matched for a metadata item to be copied to the output array.
 The keySpace will be compared to the keySpaces of the QTMetadataItems in the array via [keySpace isEqualToString:].
 If no filtering according to keySpace is desired, pass nil.
 @result			An NSArray object containing the metadata items of the specified NSArray that match the specified key and/or keySpace.
 */
+ (NSArray *)metadataItemsFromArray:(NSArray *)array withKey:(id)key keySpace:(NSString *)keySpace;

@end

#endif	// if (defined(MAC_OS_X_VERSION_10_7) && (MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_7))