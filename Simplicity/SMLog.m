//
//  SMLog.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/18/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"

NSUInteger SMLogLevel = SM_LOG_LEVEL_INFO;

static const char *logLevelName(NSUInteger level) {
    switch(level) {
        case SM_LOG_LEVEL_FATAL:   return "FF";
        case SM_LOG_LEVEL_ERROR:   return "EE";
        case SM_LOG_LEVEL_WARNING: return "WW";
        case SM_LOG_LEVEL_INFO:    return "II";
        case SM_LOG_LEVEL_DEBUG:   return "DD";
        case SM_LOG_LEVEL_NOISE:   return "NN";
    }
    return "??";
}

static const char *getFileName(const char *path) {
    const char *sep = strrchr(path, '/');
    return sep? sep+1 : path;
}

void SMFatal(const char *file, int line, const char *func) {
    SM_LOG_FATAL(@"FATAL ERROR IN %s, line %d, function %s", getFileName(file), line, func);

    abort();
}

void SMLog(NSUInteger level, const char *file, int line, const char *func, NSString *format, ...) {
    va_list args;
    va_start(args, format);

    NSLogv([NSString stringWithFormat:@"[%s] [%s:%d] %s: %@", logLevelName(level), getFileName(file), line, func, format], args);

    va_end(args);
}
