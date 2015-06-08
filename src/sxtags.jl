SXType = UInt8 # stores the type of SEXPREC

##############################################################################
##
## A table of R's SEXPREC tags from RInternals.h
##
##############################################################################

const NILSXP =      0x00 # nil = NULL
const SYMSXP =      0x01 # symbols
const LISTSXP =     0x02 # lists of dotted pairs
const CLOSXP =      0x03 # closures
const ENVSXP =      0x04 # environments
const PROMSXP =     0x05 # promises: [un]evaluated closure arguments
const LANGSXP =     0x06 # language constructs (special lists)
const SPECIALSXP =  0x07 # special forms
const BUILTINSXP =  0x08 # builtin non-special forms
const CHARSXP =     0x09 # "scalar" string type (internal only)
const LGLSXP =      0x0A # logical vectors
# 11 and 12 were factors and ordered factors in the 1990s
const INTSXP =      0x0D # integer vectors
const REALSXP =     0x0E # real variables
const CPLXSXP =     0x0F # complex variables
const STRSXP =      0x10 # string vectors
const DOTSXP =      0x11 # dot-dot-dot object
const ANYSXP = 	    0x12 # make "any" args work. Used in specifying types for symbol registration to mean anything is okay
const VECSXP =      0x13 # generic vectors
const EXPRSXP =     0x14 # expressions vectors
const BCODESXP =    0x15 # byte code
const EXTPTRSXP =   0x16 # external pointer
const WEAKREFSXP =  0x17 # weak reference
const RAWSXP =      0x18 # raw bytes
const S4SXP =       0x19 # S4, non-vector

# used for detecting PROTECT issues in memory.c
const NEWSXP =      0x1E # fresh node creaed in new page
const FREESXP =     0x1F # node released by GC

const FUNSXP =      0x63 # Closure or Builtin or Special

#=
 = Administrative SXP values
 =#
const REFSXP =            0xFF
const NILVALUE_SXP =      0xFE
const GLOBALENV_SXP =     0xFD
const UNBOUNDVALUE_SXP =  0xFC
const MISSINGARG_SXP =    0xFB
const BASENAMESPACE_SXP = 0xFA
const NAMESPACESXP =      0xF9
const PACKAGESXP =        0xF8
const PERSISTSXP =        0xF7
const CLASSREFSXP =       0xF6
const GENERICREFSXP =     0xF5
const BCREPDEF =          0xF4
const BCREPREF =          0xF3
const EMPTYENV_SXP =      0xF2
const BASEENV_SXP =       0xF1
const ATTRLANGSXP =       0xF0
const ATTRLISTSXP =       0xEF

##############################################################################
##
## R objects in the file are preceded by a UInt32 giving the type and
## some flags.  These functions unpack bits in the flags.  The isobj
## bit might be useful for distinguishing an RInteger from a factor or
## an RList from a data.frame.
##
##############################################################################

typealias RDATag UInt32

isobj(fl::RDATag) = (fl & 0x00000100) != 0
hasattr(fl::RDATag) = (fl & 0x00000200) != 0
hastag(fl::RDATag) = (fl & 0x00000400) != 0

if VERSION < v"0.4-"
    sxtype = uint8
else
    sxtype(fl::RDATag) = fl % UInt8
end
