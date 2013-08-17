//
//  RadYAML.m
//  YAML Serialization support by Mirek Rusin based on C library LibYAML by Kirill Simonov
//	Released under MIT License
//
//  Copyright 2010 Mirek Rusin
//  Copyright 2010 Stanislav Yudin
//
//  Heavily revised and condensed by Tim Burks. February 13, 2011.
//
#import "RadYAML.h"
#import "yaml.h"

#define DATEFORMAT @"yyyy-MM-dd HH:mm:ss.SSSSSS ZZZZ"

static NSDateFormatter *dateFormatter = nil;

static int YAMLSerializationDataHandler(void *string, unsigned char *buffer, size_t size)
{
    NSString *bufferString = [[NSString alloc] initWithBytes:buffer length:size encoding:NSUTF8StringEncoding];
    [((__bridge NSMutableString *) string) appendString:bufferString];
    return YES;
}

static int YAMLSerializationProcessValue(yaml_document_t *document, id value)
{
    int nodeId = 0;
    if ([value isKindOfClass:[NSDictionary class]]) {
        nodeId = yaml_document_add_mapping(document, NULL, YAML_BLOCK_MAPPING_STYLE);
        NSArray *keys = [[value allKeys] sortedArrayUsingSelector:@selector(compare:)];
        for(NSString *key in keys) {
            int keyId = YAMLSerializationProcessValue(document, key);
            id keyValue = [value objectForKey:key];
            if (keyValue && (keyValue != [NSNull null])) {
                int valueId = YAMLSerializationProcessValue(document, keyValue);
                yaml_document_append_mapping_pair(document, nodeId, keyId, valueId);
            }
        }
    }
    else if ([value isKindOfClass:[NSArray class]]) {
        nodeId = yaml_document_add_sequence(document, NULL, YAML_BLOCK_SEQUENCE_STYLE);
        for(id childValue in value) {
            int childId = YAMLSerializationProcessValue(document, childValue);
            yaml_document_append_sequence_item(document, nodeId, childId);
        }
    }
    else if ([value isKindOfClass:[NSDate class]]) {
        if (!dateFormatter) {
            dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
            [dateFormatter setDateFormat:DATEFORMAT];
        }
        NSString *printValue = [dateFormatter stringFromDate:value];
        nodeId = yaml_document_add_scalar(document, NULL, (yaml_char_t*)[printValue UTF8String], (int) [printValue length], YAML_PLAIN_SCALAR_STYLE);
    }
    else {
        if (![value isKindOfClass:[NSString class]] ) {
            value = [value stringValue];
        }
        yaml_char_t *utf8String = (yaml_char_t *) [value UTF8String];
        int length = (int) strlen((const char *) utf8String);
        nodeId = yaml_document_add_scalar(document, NULL, utf8String, length, YAML_ANY_SCALAR_STYLE);
    }
    return nodeId;
}

static yaml_document_t* YAMLSerializationToDocument(id yaml)
{
    yaml_document_t *document = (yaml_document_t*)malloc( sizeof(yaml_document_t));
    if (!document) {
        NSLog(@"Couldn't allocate memory. Please try to free memory and retry");
        return NULL;
    }
    if (!yaml_document_initialize(document, NULL, NULL, NULL, 0, 0)) {
        NSLog(@"Failed to initialize yaml document.");
        free(document);
        return NULL;
    }
    int rootId = 0;
    if ([yaml isKindOfClass:[NSDictionary class]]) {
        rootId = yaml_document_add_mapping(document, NULL, YAML_ANY_MAPPING_STYLE);
        NSArray *keys = [[yaml allKeys] sortedArrayUsingSelector:@selector(compare:)];
        for(NSString *key in keys) {
            int keyId = YAMLSerializationProcessValue(document, key);
            id value = [yaml objectForKey:key];
            if (value && (value != [NSNull null])) {
                int valueId = YAMLSerializationProcessValue(document, value);
                yaml_document_append_mapping_pair(document, rootId, keyId, valueId);
            }
        }
    }
    else if ([yaml isKindOfClass:[NSArray class]]) {
        rootId = yaml_document_add_sequence(document, NULL, YAML_ANY_SEQUENCE_STYLE);
        for(id value in yaml) {
            int valueId = YAMLSerializationProcessValue(document, value);
            yaml_document_append_sequence_item(document, rootId, valueId);
        }
    }
    else {
        NSLog(@"Objects for YAML must be either NSDictionaries or NSArrays (not %@).", NSStringFromClass([yaml class]));
        free(document);
        return NULL;
    }
    return document;
}

static int YAMLSerializationReadHandler(void *data, unsigned char *buffer, size_t size, size_t *size_read)
{
    NSInteger result = [(__bridge NSInputStream *)data read:(uint8_t *)buffer maxLength:size];
    if (result < 0) {
        result = 0;
        *size_read = (size_t) result;
        return NO;
    }
    *size_read = (size_t) result;
    return YES;
}

static id YAMLSerializationWithDocument(yaml_document_t *document)
{
    id root = nil;
    
    NSMutableArray *objects = [NSMutableArray array];
    
    // Create all objects but don't fill containers yet.
    int i = 0;
    yaml_node_t *node;
    for (node = document->nodes.start, i = 0; node < document->nodes.top; node++, i++) {
        switch (node->type) {
            case YAML_SCALAR_NODE:
            {
                id item = nil;
                
                const char *bytes = (const char *)node->data.scalar.value;
                char *endptr;
                
                if (node->data.scalar.length) {
                    if (!item) {
                        // If it can be converted to a long, it's an NSNumber.
                        long lvalue = strtol(bytes, &endptr, 0);
                        if (*endptr == 0) {
                            item = [[NSNumber alloc] initWithLong:lvalue];
                        }
                    }
                    
                    if (!item) {
                        // If it can be converted to a double, it's an NSNumber.
                        double dvalue = strtod(bytes, &endptr);
                        if (*endptr == 0) {
                            item = [[NSNumber alloc] initWithDouble:dvalue];
                        }
                    }
                }
                
                if (!item) {
                    item = [[NSMutableString alloc] initWithUTF8String:(const char *)node->data.scalar.value];
                    if (!dateFormatter) {
                        dateFormatter = [[NSDateFormatter alloc] init];
                        [dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
                        [dateFormatter setDateFormat:DATEFORMAT];
                    }
                    NSDate *date = [dateFormatter dateFromString:item];
                    if (date) {
                        item = date;
                    } else {
                        // it's a string
                    }
                }
                
                [objects addObject:item];
                if (!root) root = item;
                break;
            }
            case YAML_SEQUENCE_NODE: {
                id item = [[NSMutableArray alloc] initWithCapacity:node->data.sequence.items.top - node->data.sequence.items.start];
                [objects addObject:item];
                if (!root) root = item;
                break;
            }
            case YAML_MAPPING_NODE: {
                id item = [[NSMutableDictionary alloc] initWithCapacity:node->data.mapping.pairs.top - node->data.mapping.pairs.start];
                [objects addObject:item];
                if (!root) root = item;
                break;
            }
            default:
                break;
        }
    }
    
    // Fill containers
    for (node = document->nodes.start, i = 0; node < document->nodes.top; node++, i++) {
        switch (node->type) {
            case YAML_SEQUENCE_NODE:
                for (yaml_node_item_t *item = node->data.sequence.items.start; item < node->data.sequence.items.top; item++) {
                    [[objects objectAtIndex:i] addObject:[objects objectAtIndex:(*item - 1)]];
                }
                break;
            case YAML_MAPPING_NODE:
                for (yaml_node_pair_t *pair = node->data.mapping.pairs.start; pair < node->data.mapping.pairs.top; pair++) {
                    [[objects objectAtIndex:i] setObject:[objects objectAtIndex:(pair->value - 1)]
                                                  forKey:[objects objectAtIndex:(pair->key - 1)]];
                }
                break;
            default:
                break;
        }
    }
    
    return root;
}

@implementation NSString (RadYAML)

- (id) YAMLValue
{
    id data = [self dataUsingEncoding:NSUnicodeStringEncoding];
    if (data) {
        NSMutableArray *documents = [NSMutableArray array];
        NSInputStream *stream = [NSInputStream inputStreamWithData:data];
        [stream open];
        yaml_parser_t parser;
        if (!yaml_parser_initialize(&parser)) {
            NSLog(@"Internal error in yaml_parser_initialize(&parser).");
            return nil;
        }
        yaml_parser_set_input(&parser, YAMLSerializationReadHandler, (__bridge void *)stream);
        BOOL done = NO;
        while (!done) {
            yaml_document_t document;
            if (!yaml_parser_load(&parser, &document)) {
                NSLog(@"YAML parse error.");
                return nil;
            }
            done = !yaml_document_get_root_node(&document);
            if (!done) {
                id documentObject = YAMLSerializationWithDocument(&document);
                if (documentObject) {
                    [documents addObject: documentObject];
                }
            }
            yaml_document_delete(&document);
        }
        yaml_parser_delete(&parser);
        if ([documents count] == 1) {
            return [documents objectAtIndex:0];
        }
        else {
            return documents;
        }
    }
    else {
        return nil;
    }
}

@end

@implementation NSObject (YAMLSerialization)

- (NSString *) YAMLRepresentation
{
    NSMutableString *string = [NSMutableString string];
    yaml_emitter_t emitter;
    if (!yaml_emitter_initialize(&emitter)) {
        NSLog(@"Internal error in yaml_emitter_initialize(&emitter).");
        return nil;
    }
    yaml_emitter_set_encoding(&emitter, YAML_UTF8_ENCODING);
    yaml_emitter_set_output(&emitter, YAMLSerializationDataHandler, (__bridge void *)string);
    yaml_document_t *document = YAMLSerializationToDocument(self);
    if (!document) {
        yaml_emitter_delete(&emitter);
        return nil;
    }
    yaml_emitter_dump(&emitter, document);
    yaml_emitter_delete(&emitter);
    return string;
}

@end
