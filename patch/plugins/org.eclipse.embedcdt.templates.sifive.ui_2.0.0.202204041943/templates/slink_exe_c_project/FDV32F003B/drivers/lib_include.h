/**
 * @file lib_include.h
 * @author David Lin
 * @brief
 * @version 0.1
 * @date 2021-05-17
 *
 * @copyright Fanhai Data Tech. (c) 2021
 *
 */

#ifndef __LIB_INCLUDE_H__
#define __LIB_INCLUDE_H__

// firmware include file
#include "../../FDV32F003B/drivers/efc.h"
#include "../../FDV32F003B/drivers/iom.h"
#include "../../FDV32F003B/drivers/lptimer.h"
#include "../../FDV32F003B/drivers/sysc.h"
#include "../../FDV32F003B/drivers/timer.h"
#include "../../FDV32F003B/drivers/uart.h"
#include "../../FDV32F003B/drivers/wdt.h"

#ifdef _DEBUG
extern int __wrap_printf(const char *fmt, ...);
#define printf(...) __wrap_printf(__VA_ARGS__)
#else
#define printf(...)
#endif

#endif/*__LIB_INCLUDE_H__*/
