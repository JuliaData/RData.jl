##############################################################################
##
## Constants used as NA patterns in R.
## 0x000007a2 == UInt32(1954) is a non-standard addition to NaN bit pattern
## to discriminate NA from NaN.
## (I assume 1954 is the year of Ross's birth or something like that.)
## Note that float NA are defined as UInt64 to workaround the win32 ABI
# issue (see JuliaStats/RData.jl#5 and JuliaLang/julia#17195).
##
##############################################################################

if ENDIAN_BOM == 0x01020304
    const R_NA_FLOAT64 = 0x000007a27ff00000
else
    const R_NA_FLOAT64 = 0x7ff00000000007a2
end

const R_NA_INT32 = typemin(Int32)
const R_NA_STRING = "NA"

const LONG_VECTOR_SUPPORT = (Sys.WORD_SIZE > 32) # disable long vectors support on 32-bit machines

if LONG_VECTOR_SUPPORT
    typealias RVecLength Int64
else
    typealias RVecLength Int
end

typealias RString UTF8String     # default String container for R string
typealias Hash Dict{RString, Any}

const emptyhash = Hash()
const emptyhashkey = RString("\0")
