##############################################################################
##
## Constants used as NA patterns in R.
## (I assume 1954 is the year of Ross's birth or something like that.)
##
##############################################################################

if ENDIAN_BOM == 0x01020304
    const R_NA_FLOAT64 = reinterpret(Float64, [0x7ff00000, @compat(UInt32(1954))])[1]
else
    const R_NA_FLOAT64 = reinterpret(Float64, [@compat(UInt32(1954)), 0x7ff00000])[1]
end
const R_NA_INT32 = typemin(Int32)
const R_NA_STRING = "NA"

LONG_VECTOR_SUPPORT = (WORD_SIZE > 32) # disable long vectors support on 32-bit machines

if LONG_VECTOR_SUPPORT
    typealias RVecLength Int64
else
    typealias RVecLength Int
end
