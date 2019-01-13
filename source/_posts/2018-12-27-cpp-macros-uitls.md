---
title: C++ Debug常用的宏定义记录
date: 2018-12-27 09:19:44
update: 2018-12-27 09:19:44
categories: C++
tags: [C++, macro, debug, 宏定义]
---

记录一些C++ Debug常用的宏定义

<!--more-->

```
// reference from: https://github.com/Project-OSRM/osrm-backend

#ifndef TIME_UTILS_H_
#define TIME_UTILS_H_

#include "chrono"


// Recording start
#define TIMER_START(_X) auto _X##_start = std::chrono::steady_clock::now(), _X##_stop = _X##_start

// Recording end
#define TIMER_STOP(_X) _X##_stop = std::chrono::steady_clock::now()

// return duration time with nanosecond
#define TIMER_NSEC(_X)                                                                             \
    std::chrono::duration_cast<std::chrono::nanoseconds>(_X##_stop - _X##_start).count()

// return duration time with microsecond
#define TIMER_USEC(_X)                                                                             \
    std::chrono::duration_cast<std::chrono::microseconds>(_X##_stop - _X##_start).count()

// return duration time with millisecond
#define TIMER_MSEC(_X)                                                                             \
    (0.000001 *                                                                                    \
     std::chrono::duration_cast<std::chrono::nanoseconds>(_X##_stop - _X##_start).count())

// return duration time with seconds
#define TIMER_SEC(_X)                                                                              \
    (0.000001 *                                                                                    \
     std::chrono::duration_cast<std::chrono::microseconds>(_X##_stop - _X##_start).count())

// return duration time with minutes
#define TIMER_MIN(_X)                                                                              \
    std::chrono::duration_cast<std::chrono::minutes>(_X##_stop - _X##_start).count()


#define ERROR(...) \
do{ \
    fprintf(stderr, "[ERROR  ]%s %s(Line %d): ",__FILE__,__FUNCTION__,__LINE__); \
    fprintf(stderr, __VA_ARGS__); \
    fprintf(stdout, "\n"); \
}while (0)

#define WARNING(...) \
do{ \
    fprintf(stdout, "[WARNING]%s %s(Line %d): ",__FILE__,__FUNCTION__,__LINE__); \
    fprintf(stdout, __VA_ARGS__); \
    fprintf(stdout, "\n"); \
}while (0)

#define INFO(...) \
do{ \
    fprintf(stdout, "[INFO   ]%s %s(Line %d): ",__FILE__,__FUNCTION__,__LINE__); \
    fprintf(stdout, __VA_ARGS__); \
    fprintf(stdout, "\n"); \
}while (0)

#ifdef DEBUG
#define DBG(...) \
do{ \
    fprintf(stdout, "[DEBUG  ]%s %s(Line %d): ",__FILE__,__FUNCTION__,__LINE__); \
    fprintf(stdout, __VA_ARGS__); \
    fprintf(stdout, "\n"); \
}while(0)

// Recording start
#define DBG_TIMER_START(_X) auto _X##_start = std::chrono::steady_clock::now(), _X##_stop = _X##_start

// Recording end
#define DBG_TIMER_STOP(_X) _X##_stop = std::chrono::steady_clock::now()

#define DBG_TIMER_MSEC(_X) \
(0.000001 *  \
std::chrono::duration_cast<std::chrono::nanoseconds>(_X##_stop - _X##_start).count())
#else
#define DBG(...)
#define DBG_TIMER_START(_X)
#define DBG_TIMER_STOP(_X)
#define DBG_TIMER_MSEC(_X)
#endif


#endif //TIME_UTILS_H_
```