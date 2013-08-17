//
//  RadYAML.h
//  YAML Serialization support by Mirek Rusin based on C library LibYAML by Kirill Simonov
//	Released under MIT License
//
//  Copyright 2010 Mirek Rusin
//	Copyright 2010 Stanislav Yudin
//
//  Heavily revised and condensed by Tim Burks. February 13, 2011.
//

#import <Foundation/Foundation.h>

@interface NSString (RadYAML) 
- (id) YAMLValue;
@end

@interface NSObject (RadYAML)
- (id) YAMLRepresentation;
@end

