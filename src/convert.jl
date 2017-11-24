# converters from selected RSEXPREC to Hash
# They are used to translate SEXPREC attributes into Hash

function Base.convert(::Type{Hash}, pl::RPairList)
    res = Hash()
    for i in 1:length(pl.items)
        setindex!(res, pl.items[i], pl.tags[i])
    end
    res
end

##############################################################################
##
## Conversion of intermediate R objects into DataArray and DataFrame objects
##
##############################################################################

namask(rl::RLogicalVector) = BitArray(rl.data .== R_NA_INT32)
namask(ri::RIntegerVector) = BitArray(ri.data .== R_NA_INT32)
namask(rn::RNumericVector) = BitArray(map(isna_float64, reinterpret(UInt64, rn.data)))
# if re or im is NA, the whole complex number is NA
# FIXME avoid temporary Vector{Bool}
namask(rc::RComplexVector) = BitArray([isna_float64(v.re) || isna_float64(v.im) for v in reinterpret(Complex{UInt64}, rc.data)])
namask(rv::RNullableVector) = rv.na

DataArrays.data(rv::RVEC) = DataArray(rv.data, namask(rv))

function DataArrays.data(ri::RIntegerVector)
    if !isfactor(ri) return DataArray(ri.data, namask(ri)) end
    # convert factor into PooledDataArray
    pool = getattr(ri, "levels", emptystrvec)
    sz = length(pool)
    REFTYPE = sz <= typemax(UInt8)  ? UInt8 :
              sz <= typemax(UInt16) ? UInt16 :
              sz <= typemax(UInt32) ? UInt32 :
                                      UInt64
    dd = ri.data
    dd[namask(ri)] = 0
    refs = convert(Vector{REFTYPE}, dd)
    return PooledDataArray(DataArrays.RefArray(refs), pool)
end

# convert R logical vector (uses Int32 to store values) into DataVector{Bool}
DataArrays.data(rl::RLogicalVector) =
    return DataArray(Bool[x != 0 for x in rl.data], namask(rl))

function sexp2julia(rex::RSEXPREC)
    warn("Conversion of $(typeof(rex)) to Julia is not implemented")
    return nothing
end

function sexp2julia(rv::RVEC)
    # FIXME dimnames
    # FIXME forceDataArrays option to always convert to DataArray
    nas = namask(rv)
    hasna = any(nas)
    if class(rv) == ["Date"]
        return date2julia(rv, hasna, nas)
    elseif class(rv) == ["POSIXct"; "POSIXt"]
        return datetime2julia(rv, hasna, nas)
    elseif hasnames(rv)
        # if data has no NA, convert to simple Vector
        return DictoVec(hasna ? DataArray(rv.data, nas) : rv.data, names(rv))
    else
        hasdims = hasdim(rv)
        if !hasdims && length(rv.data)==1
            # scalar
            # FIXME handle NAs
            # if hasna
            return rv.data[1]
        elseif !hasdims
            # vectors
            return hasna ? DataArray(rv.data, nas) : rv.data
        else
            # matrices and so on
            dims = tuple(convert(Vector{Int64}, getattr(rv, "dim"))...)
            return hasna ? DataArray(reshape(rv.data, dims), reshape(nas, dims)) :
                         reshape(rv.data, dims)
        end
    end
end

function sexp2julia(rl::RList)
    if isdataframe(rl)
        # FIXME remove Any type assertion workaround
        DataFrame(Any[data(col) for col in rl.data], map(identifier, names(rl)))
    elseif hasnames(rl)
        DictoVec(Any[sexp2julia(item) for item in rl.data], names(rl))
    else
        # FIXME return DictoVec if forceDictoVec is on
        map(sexp2julia, rl.data)
    end
end

function date2julia(rv, hasna, nas)
    @assert class(rv) == ["Date"]
    epoch_conv = 719528 # Dates.date2epochdays(Date("1970-01-01"))
    if hasna
        dates = DataArray([isna ? Date() : Dates.epochdays2date(dtfloat + epoch_conv)
                           for (isna, dtfloat) in zip(nas, rv.data)],
                          nas)
    else
        dates = Dates.epochdays2date.(rv.data .+ epoch_conv)
    end
    if hasnames(rv)
        dates = DictoVec(dates, names(rv))
    end
    return length(dates) == 1 & !hasnames(rv) ? dates[1] : dates
end

# does not handle timezone differences because R stores the timezone in the "Z"
# format, but this is ambiguous therefore TimeZones.jl can't convert would be
# nice if there was an option to be more specific about the timezone
# ref: http://timezonesjl.readthedocs.io/en/latest/conversions/
function datetime2julia(rv, hasna, nas)
    @assert class(rv) == ["POSIXct"; "POSIXt"]
    if hasna
        datetimes = DataArray([isna ? DateTime() : Dates.unix2datetime(dtfloat)
                               for (isna, dtfloat) in zip(nas, rv.data)],
                              nas)
    else
        datetimes =  Dates.unix2datetime.(rv.data)
    end
    if hasnames(rv)
        datetimes = DictoVec(datetimes, names(rv))
    end
    return length(datetimes) == 1 & !hasnames(rv) ? datetimes[1] : datetimes
end

