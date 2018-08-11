##############################################################################
##
## Constants used as NA patterns in R.
##
##############################################################################

"""
Non-standard addition to NaN bit pattern to discriminate NA from NaN.
0x000007a2 == UInt32(1954)
(I assume 1954 is the year of Ross's birth or something like that.)
"""
const R_NA_FLOAT64_LOW = 0x000007a2

## Note that float NA are defined as UInt64 to workaround the win32 ABI
## issue (see JuliaData/RData.jl#5 and JuliaLang/julia#17195).
if ENDIAN_BOM == 0x01020304
    const R_NA_FLOAT64 = ((R_NA_FLOAT64_LOW % UInt64) << 32) | (Base.exponent_mask(Float64) >> 32)
else
    const R_NA_FLOAT64 = Base.exponent_mask(Float64) | R_NA_FLOAT64_LOW
end

# Some .rda files might use R_NA_FLOAT64 = 0x7ff80000000007a2,
# so the proper check for NA: isnan(x) & lowword(x) == R_NA_FLOAT64_LOW
isna_float64(x::UInt64) =
    ((x & Base.exponent_mask(Float64)) == Base.exponent_mask(Float64)) &&
    ((x % UInt32) == R_NA_FLOAT64_LOW)

const R_NA_INT32 = typemin(Int32)
const R_NA_STRING = "NA"

const LONG_VECTOR_SUPPORT = (Sys.WORD_SIZE > 32) # disable long vectors support on 32-bit machines

const RVecLength = LONG_VECTOR_SUPPORT ? Int64 : Int

const RString = String     # default String container for R string
const Hash = Dict{RString, Any}

const emptyhash = Hash()
const emptyhashkey = RString("\0")

const R_Date_Class = ["Date"]
const R_POSIXct_Class = ["POSIXct", "POSIXt"]

