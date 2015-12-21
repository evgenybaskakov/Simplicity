//
//  SMLog.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/18/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#define SM_LOG_LEVEL_FATAL   0
#define SM_LOG_LEVEL_ERROR   1
#define SM_LOG_LEVEL_WARNING 2
#define SM_LOG_LEVEL_INFO    3
#define SM_LOG_LEVEL_DEBUG   4
#define SM_LOG_LEVEL_NOISE   5

#define SM_LOG(level, ...) do {                                      \
    if(level <= SMLogLevel) {                                        \
        SMLog(level, __FILE__, __LINE__, __FUNCTION__, __VA_ARGS__); \
    }                                                                \
} while(0)

#define SM_FATAL(...) do {                                           \
    SM_LOG_FATAL(__VA_ARGS__);                                       \
    SMFatal(__FILE__, __LINE__, __FUNCTION__);                       \
} while(0)

#define SM_LOG_FATAL(...)   SM_LOG(SM_LOG_LEVEL_FATAL, __VA_ARGS__)
#define SM_LOG_ERROR(...)   SM_LOG(SM_LOG_LEVEL_ERROR, __VA_ARGS__)
#define SM_LOG_WARNING(...) SM_LOG(SM_LOG_LEVEL_WARNING, __VA_ARGS__)
#define SM_LOG_INFO(...)    SM_LOG(SM_LOG_LEVEL_INFO, __VA_ARGS__)
#define SM_LOG_DEBUG(...)   SM_LOG(SM_LOG_LEVEL_DEBUG, __VA_ARGS__)
#define SM_LOG_NOISE(...)   SM_LOG(SM_LOG_LEVEL_NOISE, __VA_ARGS__)

extern NSUInteger SMLogLevel;

void SMFatal(const char *file, int line, const char *func);
void SMLog(NSUInteger level, const char *file, int line, const char *func, NSString *format, ...) NS_FORMAT_FUNCTION(5,6);
