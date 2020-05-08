/*=============================================================================
 *  @brief C implementation of DPI methods 
 *  @author Jonathan Bromley, Verilab (www.verilab.com)
 * =============================================================================
 *
 *                      svlib SystemVerilog Utilities Library
 *
 * @File: svlib_dpi.c
 *
 * Copyright 2014 Verilab, Inc.
 * 
 *    Licensed under the Apache License, Version 2.0 (the "License");
 *    you may not use this file except in compliance with the License.
 *    You may obtain a copy of the License at
 * 
 *        http://www.apache.org/licenses/LICENSE-2.0
 * 
 *    Unless required by applicable law or agreed to in writing, software
 *    distributed under the License is distributed on an "AS IS" BASIS,
 *    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *    See the License for the specific language governing permissions and
 *    limitations under the License.
=============================================================================*/

#if __STDC_VERSION__ >= 199901L
#define _XOPEN_SOURCE 600
#else
#define _XOPEN_SOURCE 500
#endif /* __STDC_VERSION__ */

#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <glob.h>
#include <time.h>
#include <regex.h>
#include <assert.h>

#include <veriuser.h>
#include <vpi_user.h>
#include <svdpi.h>

#define STRINGIFY(x) MACROHASH(x)
#define MACROHASH(x) #x

#define SVLIB_STRING_BUFFER_START_SIZE       (256)
#define SVLIB_STRING_BUFFER_LONGEST_PATHNAME (8192)

#ifdef _CPLUSPLUS
extern "C" {
#endif

#include "../svlib_shared_c_sv.h"

static char*  libStringBuffer = NULL;
static size_t libStringBufferSize = 0;

/*--------------------------------------------------------------------------
 * FOR INTERNAL USE BY SVLIB ONLY:
 *--------------------------------------------------------------------------
 * Get a new string buffer of given size.
 * If size<=0 and there is currently no buffer,
 * create one with the default size. If size=0 and
 * there is already a buffer, return it. If size<0
 * and there is already a buffer, double its existing
 * size and then return it.
 */ 
static char* getLibStringBuffer(size_t size) {
  if (size<=0) {
    if (libStringBuffer==NULL) {
      return getLibStringBuffer(SVLIB_STRING_BUFFER_START_SIZE);
    } else if (size == 0) {
      return libStringBuffer;
    } else {
      return getLibStringBuffer(2*libStringBufferSize);
    }
  } else if (libStringBufferSize < size) {
    char* buf = malloc(size);
    if (buf == NULL) {
      /* Report the error and return the existing buffer, whatever it is */
      perror("PROBLEM in SvLib::getLibStringBuffer: cannot malloc");
    } else {
      free(libStringBuffer);
      libStringBuffer = buf;
      libStringBufferSize = size;
    }
  }
  return libStringBuffer;
}

static size_t getLibStringBufferSize() {
  if (libStringBuffer==NULL) {
    return 0;
  } else {
    return libStringBufferSize;
  }
}

/*--------------------------------------------------------------------------
 * FOR INTERNAL USE BY SVLIB ONLY:
 *--------------------------------------------------------------------------
 * Mechanism to retrieve an array of strings from C into SV.
 * A function such as 'glob' whose main result is an array of strings
 * will construct such an array in internal storage here, then return
 * a chandle pointing to the sa_buf_struct that records the array of strings
 * and svlib's progress through collecting them.
 * Subsequent calls to svlib_dpi_imported_saBufNext with this chandle will then
 * serve up the strings one by one, finally returning with the chandle set
 * to null to indicate that all the strings have been consumed and the 
 * C-side internal storage has been freed and is no longer accessible.
 */

/* Each different data source will require its own mem-free callback. */
typedef void (*freeFunc_decl)(saBuf_p);

typedef struct saBuf {
  char        ** scan;         /* pointer to the current array element       */
  freeFunc_decl  freeFunc;     /* function to call on exhaustion             */
  void         * pAppData;     /* pointer to app-specific data               */
  int            userData;     /* general-purpose int, not used by saBufNext */
  struct saBuf * link;         /* general-purpose link ptr                   */
  struct saBuf * sanity_check; /* pointer-to-self for checking               */
} saBuf_s, *saBuf_p;

static int32_t saBufCreate(size_t dataBytes, freeFunc_decl ff, saBuf_p *created) {
  *created = NULL;
  saBuf_p sa = malloc(sizeof(saBuf_s));
  if (sa == NULL) {
    return ENOMEM;
  }
  sa->pAppData = malloc(dataBytes);
  if (sa->pAppData == NULL) {
    free(sa);
    return ENOMEM;
  }
  sa->sanity_check = sa;
  sa->link         = NULL;
  sa->freeFunc     = ff;
  sa->scan         = NULL;
  sa->userData     = 0;
  *created         = sa;
  return 0;
}

/*-------------------------------------------------------------------------------
 * import "DPI-C" function int svlib_dpi_imported_saBufNext(inout chandle h, output string s);
 *-------------------------------------------------------------------------------
 */
extern int32_t svlib_dpi_imported_saBufNext(void **h, const char **s) {
  *s = NULL;
  if (*h == NULL) {
    return 0;
  }
  saBuf_p p = (saBuf_p)(*h);
  if (p->sanity_check != p) {
    return ENOMEM;
  }
  *s = *(p->scan);
  p->scan++;
  if (*s == NULL) {
    *h = NULL;
    if (p->freeFunc != NULL) {
      (*(p->freeFunc))(p);
    }
  }
  return 0;
}


/*-------------------------------------------------------------------------------
 * import "DPI-C" function chandle svlib_dpi_imported_getVlogInfo(
 *                              output string product, output string version);
 *-------------------------------------------------------------------------------
 * Function to set up the results of vpi_get_vlog_info() ready for consumption.
 *-------------------------------------------------------------------------------
 */

extern void * svlib_dpi_imported_getVlogInfo(
      char   ** product,
      char   ** version
    ) {
  int             status;
  s_vpi_vlog_info info;
  
  /* Ensure result values are zero for easy error handling */
  *version = NULL;
  *product = NULL;
  
  status = vpi_get_vlog_info(&info);
  if (!status) { /*1=ok, 0=fail*/
    /*
     * Error: get_vlog_info failed for some reason.
     * This is unlikely, but there's nothing we can do about it.
     * Just report it.
     */
    return NULL;
  }
  *version = info.version;
  *product = info.product;
  return (void*) info.argv;  
}

#define ARGV_STACK_PTR_SIZE 32

/*-------------------------------------------------------------------------------
 * import "DPI-C" function string svlib_dpi_imported_getVlogInfoNext(inout chandle hnd);
 *-------------------------------------------------------------------------------
 * Function to get successive strings from already-setup vlog_info
 *-------------------------------------------------------------------------------
 * Some parts taken, with small modifications, from Accellera's UVM DPI code.
 * Accellera's authorship is acknowledged. The functionality is slightly 
 * different from Accellera's, in that all nested -f response files are
 * flattened so that all arguments appear as if on a single command line.
 * This lowest-common-denominator behaviour matches some existing tools.
 *-------------------------------------------------------------------------------
 */

extern const char * svlib_dpi_imported_getVlogInfoNext (void** info_argv) {
  static char*** argv_stack = NULL;
  static int argv_stack_ptr = 0; // stack ptr

  if(argv_stack == NULL)
  {
    argv_stack = (char***) malloc (sizeof(char**)*ARGV_STACK_PTR_SIZE);
    argv_stack[0] = (char**)*info_argv;
  }

  // until we have returned a value
  while (1)
  {
    // at end of current array?, pop stack
    if (*argv_stack[argv_stack_ptr]  == NULL)
    {
      // stack empty?
      if (argv_stack_ptr == 0)
      {
        // reset stack for next time
        argv_stack = NULL;
        argv_stack_ptr = 0;
        // return completion
        *info_argv = NULL;
        return NULL;
      }
      // pop stack
      --argv_stack_ptr;
      continue;
    }
    else
    {
      // check for -f indicating pointer to new array
      if(0==strcmp(*argv_stack[argv_stack_ptr], "-f") ||
         0==strcmp(*argv_stack[argv_stack_ptr], "-F") )
      {
        // bump past -f at current level
        ++argv_stack[argv_stack_ptr]; 
        // push -f array argument onto stack
        argv_stack[argv_stack_ptr+1] = (char **)*argv_stack[argv_stack_ptr];
        // bump past -f argument at current level
        ++argv_stack[argv_stack_ptr]; 
        // update stack pointer
        ++argv_stack_ptr;
        // skip over filename string at start of new -f argument
        ++argv_stack[argv_stack_ptr]; 
        assert(argv_stack_ptr < ARGV_STACK_PTR_SIZE);
      }
      else
      {      
        // return current and move to next
        char *r = *argv_stack[argv_stack_ptr];
        ++argv_stack[argv_stack_ptr];
        return r;
      }
    }
  }
}


/*-------------------------------------------------------------------
 * import "DPI-C" function string svlib_dpi_imported_getCErrStr(input int errnum);
 *-------------------------------------------------------------------
 */
extern const char* svlib_dpi_imported_getCErrStr(int32_t errnum) {
  return strerror(errnum);
}

/*----------------------------------------------------------------
 * import "DPI-C" function int svlib_dpi_imported_getcwd(output string result);
 *----------------------------------------------------------------
 */
extern int32_t svlib_dpi_imported_getcwd(char ** p_result) {

  size_t  bSize = SVLIB_STRING_BUFFER_START_SIZE;
  char  * buf;

  while (1) {
    buf   = getLibStringBuffer(bSize);
    bSize = getLibStringBufferSize();
    if (NULL != getcwd(buf, bSize)) {
      *p_result = buf;
      return 0;
    } else if (errno==ERANGE) {
      if (bSize >= SVLIB_STRING_BUFFER_LONGEST_PATHNAME) {
        *p_result = "Working directory pathname exceeds maximum buffer length " 
                    STRINGIFY(SVLIB_STRING_BUFFER_LONGEST_PATHNAME);
        return errno;
      } else {
        bSize *= 2;
      }
    } else {
      *p_result = strerror(errno);
      return errno;
    }
  }
}

/*----------------------------------------------------------------
 * import "DPI-C" function int svlib_dpi_imported_getenv(
 *                           string envVar, output string result);
 *----------------------------------------------------------------
 */
extern int32_t svlib_dpi_imported_getenv(char *envVar, char ** p_result) {
  char * envStr = getenv(envVar);
  if (envStr == NULL) {
    *p_result = NULL;
    return 1;
  } else {
    *p_result = envStr;
    return 0;
  }
}

/*----------------------------------------------------------------
 *   import "DPI-C" function int svlib_dpi_imported_fileStat(
 *                            input  longint epochSeconds,
 *                            output int     timeItems[tmARRAYSIZE]);
 *----------------------------------------------------------------
 */
 
static int isLeapYear(int year) {
  return ((year%4==0) && (year%100!=0)) || (year%400==0);
}

extern int32_t svlib_dpi_imported_localTime(int64_t epochSeconds, int *timeItems) {
  struct tm timeParts;
  time_t t = epochSeconds;
  if (NULL == localtime_r(&t, &timeParts))
    return 1;  /*exceedingly unlikely */
  timeItems[tmSEC]   = timeParts.tm_sec;
  timeItems[tmMIN]   = timeParts.tm_min;
  timeItems[tmHOUR]  = timeParts.tm_hour;
  timeItems[tmMDAY]  = timeParts.tm_mday;
  timeItems[tmMON]   = timeParts.tm_mon;
  timeItems[tmYEAR]  = timeParts.tm_year;
  timeItems[tmWDAY]  = timeParts.tm_wday;
  timeItems[tmYDAY]  = timeParts.tm_yday;
  timeItems[tmISDST] = timeParts.tm_isdst;
  timeItems[tmISLY]  = isLeapYear(timeParts.tm_year+1900);

  return 0;
}

/*----------------------------------------------------------------
 * import "DPI-C" function int svlib_dpi_imported_timeFormat(
 *                                       input  longint epochSeconds, 
 *                                       input  string  format, 
 *                                       output string  formatted);
 *----------------------------------------------------------------
 */
extern int32_t svlib_dpi_imported_timeFormat(int64_t epochSeconds, const char *format, const char **formatted) {
  
  size_t bSize = SVLIB_STRING_BUFFER_START_SIZE;
  char * buf;
  time_t t = epochSeconds;  /* to keep C library time functions happy */
  
  struct tm timeParts;        /* broken-down time */
  
  /* Make the result an empty string iff user's fmt is an empty string */
  if (strlen(format)==0) {
    *formatted = "";
  }
  
  (void) localtime_r(&t, &timeParts);
  
  while (1) {
    buf   = getLibStringBuffer(bSize);
    bSize = getLibStringBufferSize();
    if (0 != strftime(buf, bSize, format, &timeParts)) {
      *formatted = buf;
      return 0;
    } else if (bSize >= SVLIB_STRING_BUFFER_LONGEST_PATHNAME) {
      *formatted = "timeFormat result exceeds maximum buffer length " 
                  STRINGIFY(SVLIB_STRING_BUFFER_LONGEST_PATHNAME);
      return ERANGE;
    } else {
      bSize *= 2;
    }
  }
}
extern int32_t svlib_dpi_imported_timeFormatST(int64_t epochSeconds, const char **timeST) {
  
  size_t bSize = SVLIB_STRING_BUFFER_START_SIZE;
  char * buf;
  int    nChars;
  time_t t = epochSeconds;  /* to keep C library time functions happy */
  
  struct tm timeParts;        /* broken-down time */

  (void) localtime_r(&t, &timeParts);
  
  while (1) {
    buf    = getLibStringBuffer(bSize);
    bSize  = getLibStringBufferSize();
    nChars = snprintf(buf, bSize, "Stardate %2d%03d.%01d",
               (timeParts.tm_year - 46),
               (((timeParts.tm_yday) * 1000) /
                (365 + isLeapYear(timeParts.tm_year+1900))),
                (((timeParts.tm_hour * 60) + timeParts.tm_min)/144));
    if (nChars<bSize) {
      *timeST = buf;
      return 0;
    } else {
      bSize = nChars+1;
      if (bSize >= SVLIB_STRING_BUFFER_LONGEST_PATHNAME) {
        *timeST = "";
        return ERANGE;
      }
    }
  }
}

/*----------------------------------------------------------------
 *   import "DPI-C" function int svlib_dpi_imported_globStart(
 *                            input  string pattern,
 *                            output chandle h,
 *                            output int     count );
 *----------------------------------------------------------------
 */
static void glob_freeFunc(saBuf_p p) {
  if (p==NULL) return;
  globfree((glob_t*)(p->pAppData));
  free(p);
}

extern int32_t svlib_dpi_imported_globStart(const char *pattern, void **h, uint32_t *number) {
  int32_t result;
  saBuf_p sa;
  *number = 0;
  *h = NULL;
  result = saBufCreate(sizeof(glob_t), glob_freeFunc, &sa);
  if (result) {
    return result;
  }
  result = glob(pattern, GLOB_ERR | GLOB_MARK, NULL, sa->pAppData);
  switch (result) {
    case GLOB_NOSPACE:
      glob_freeFunc(sa);
      return ENOMEM;
    case GLOB_ABORTED:
      glob_freeFunc(sa);
      return EACCES;
    case GLOB_NOMATCH:
      *number  = 0;
      *h       = NULL;
      glob_freeFunc(sa);
      return 0;
    case 0:
      sa->scan = ((glob_t*)(sa->pAppData))->gl_pathv;
      *number  = ((glob_t*)(sa->pAppData))->gl_pathc;
      *h = (void*) sa;
      return 0;
    default:
      glob_freeFunc(sa);
      return ENOTSUP;
  }
}

typedef struct stat s_stat, *p_stat;

/*----------------------------------------------------------------
 *   import "DPI-C" function int svlib_dpi_imported_fileStat(
 *                            input  string  path,
 *                            input  int     asLink,
 *                            output longint stats[statARRAYSIZE]);
 *----------------------------------------------------------------
 */
extern int32_t svlib_dpi_imported_fileStat(const char *path, int asLink, int64_t *stats) {
  s_stat s;
  uint32_t e;
  if (asLink) {
    /* if *path is a symlink, don't follow the link but stat it */
    e = lstat(path, &s);
  } else {
    /* normal stat, follow symlink */
    e = stat(path, &s);
 }
  if (e) {
    return errno;
  } else {
    stats[statMTIME] = s.st_mtime;
    stats[statATIME] = s.st_atime;
    stats[statCTIME] = s.st_ctime;
    stats[statSIZE]  = s.st_size;
    stats[statUID]   = s.st_uid;
    stats[statGID]   = s.st_gid;
    stats[statMODE]  = s.st_mode;
    return 0;
  }
}

/*----------------------------------------------------------------
 *   import "DPI-C" function void svlib_dpi_imported_hiResTime(
 *                                   input  int     getResolution,
 *                                   output longint seconds,
 *                                   output longint nanoseconds);
 *----------------------------------------------------------------
 */
extern void svlib_dpi_imported_hiResTime(
    int getResolution,
    int64_t *seconds,
    int64_t *nanoseconds
  ) {
  struct timespec t;
  if (getResolution) {
    (void) clock_getres(CLOCK_REALTIME, &t);
  } else {
    (void) clock_gettime(CLOCK_REALTIME, &t);
  }
  *nanoseconds = t.tv_nsec;
  *seconds     = t.tv_sec;
}

/*----------------------------------------------------------------
 *  import "DPI-C" function string svlib_dpi_imported_regexErrorString(input int err, input string re);
 *----------------------------------------------------------------
 */
extern const char* svlib_dpi_imported_regexErrorString(int32_t err, const char* re) {
  uint32_t actSize, bSize;
  regex_t  compiled;
  char* buf;
  err = regcomp(&compiled, re, REG_EXTENDED);
  if (!err) {
    buf = NULL;
  } else {
    /* First, try to get result into existing buffer first. */
    actSize = 0;
    do {
      buf = getLibStringBuffer(actSize);
      bSize = getLibStringBufferSize();
      actSize = regerror(err, &compiled, buf, bSize);
      /* But resize buffer to fit if required. */
    } while (actSize > bSize);
  }
  regfree(&compiled);
  return buf;
/*
  switch (err) {
    case REG_BADBR : return
              "Invalid use of back reference operator";
    case REG_BADPAT : return
              "Invalid use of pattern operators such as group or list";
    case REG_BADRPT : return
              "Invalid use of repetition operators";
    case REG_EBRACE : return
              "Un-matched brace interval operators";
    case REG_EBRACK : return
              "Un-matched bracket list operators";
    case REG_ECOLLATE : return
              "Invalid collating element";
    case REG_ECTYPE : return
              "Unknown character class name";
    case REG_EEND : return
              "Non-specific error, not defined by POSIX.2";
    case REG_EESCAPE : return
              "Trailing backslash";
    case REG_EPAREN : return
              "Un-matched parenthesis group operators";
    case REG_ERANGE : return
              "Invalid use of the range operator";
    case REG_ESIZE : return
              "Compiled RE requires a pattern buffer larger than 64Kb";
    case REG_ESPACE : return
              "The regex routines ran out of memory";
    case REG_ESUBREG : return
              "Invalid back reference to a subexpression";
  }
  return "Unknown regular expression error";
*/
}

/*----------------------------------------------------------------
 *   import "DPI-C" function int svlib_dpi_imported_regexRun(
 *                            input  string re,
 *                            input  string str,
 *                            input  int    options,
 *                            input  int    startPos,
 *                            output int    matchCount,
 *                            output int    matchList[]);
 *----------------------------------------------------------------
*/
extern uint32_t svlib_dpi_imported_regexRun(
    const char *re,
    const char *str,
    int32_t     options,
    int32_t     startPos,
    int32_t    *matchCount,
    svOpenArrayHandle matchList
  ) {
  uint32_t result;
  regex_t    compiled;
  regmatch_t * matches;
  uint32_t numMatches;
  uint32_t i;
  uint32_t cflags;
  
  /* initialize result */
  *matchCount = 0;
  
  /* result array checks */
  if (svDimensions(matchList) != 1) {
    io_printf("svDimensions=%d, should be 1\n", svDimensions(matchList));
    return -1;
  }
  numMatches = svSizeOfArray(matchList) / sizeof(uint32_t);
  if (numMatches != 0) {
    if ((numMatches % 2) != 0) {
      io_printf("Odd number of elements in matchList\n");
      return -1;
    }
    numMatches /= 2;
    /* We are obliged to assume that the array has ascending range
     * because IUS doesn't yet support svIncrement. In practice this
     * is not a problem because the open array is always supplied
     * by a calling routine that is fully under the library's control.
     * if (svIncrement(matchList,1)>0) {
     *   io_printf("Descending subscripts in array!\n");
     *   return -1;
     * }
     */
    if (svLeft(matchList, 1) != 0) {
      io_printf("svLeft=%d, should be 0\n", svLeft(matchList,1));
      return -1;
    }
    matches = malloc(numMatches * sizeof(regmatch_t));
  }
  
  cflags = REG_EXTENDED;
  if (options & regexNOCASE) cflags |= REG_ICASE;
  if (options & regexNOLINE) cflags |= REG_NEWLINE;
  result = regcomp(&compiled, re, cflags);
  if (result) {
    regfree(&compiled);
    return result;
  }
  
  *matchCount = compiled.re_nsub+1;
  result = regexec(&compiled, &(str[startPos]), numMatches, matches, 0);
  if (result == 0) {
    /* successful match: copy matches into SV from struct[] */
    for (i=0; i<numMatches && i<*matchCount; i++) {
      if (matches[i].rm_so < 0) {
        *(regoff_t*)(svGetArrElemPtr1(matchList, 2*i  )) = -1;
        *(regoff_t*)(svGetArrElemPtr1(matchList, 2*i+1)) = -1;
      } else {
        *(regoff_t*)(svGetArrElemPtr1(matchList, 2*i  )) = matches[i].rm_so + startPos;
        *(regoff_t*)(svGetArrElemPtr1(matchList, 2*i+1)) = matches[i].rm_eo + startPos;
      }
    }
  } else if (result == REG_NOMATCH) {
    /* no match, that's OK, we return matchCount==0 */
    result = 0;
    *matchCount = 0;
  }
  regfree(&compiled);
  if (numMatches) free(matches);
  return result;
}


/*----------------------------------------------------------------
 * import "DPI-C" function int svlib_dpi_imported_access(
 *              input string path, input int mode, output int ok);
 *----------------------------------------------------------------
 */
extern int32_t svlib_dpi_imported_access(char *path, int mode, int *ok) {
  int flag;
  int err;
  
  if (mode == accessEXISTS) {
    flag = F_OK;
  } else {
    flag = 0;
    if (mode & accessREAD)  flag |= R_OK; 
    if (mode & accessWRITE) flag |= W_OK; 
    if (mode & accessEXEC)  flag |= X_OK;
  }
  
  err = access(path, flag);
  *ok = (err == 0);
  if ((err == EACCES) || (err == EROFS)) err = 0;
  
  return err;

}


#ifdef _CPLUSPLUS
}
#endif
