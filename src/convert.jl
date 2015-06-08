# converters from selected RSEXPREC to Hash
# They are used to translate SEXPREC attributes into Hash

function Base.convert(::Type{Hash}, pl::RPairList)
    res = Hash()
    for i in 1:length(pl.items)
        setindex!(res, pl.items[i], pl.tags[i])
    end
    res
end

function Base.convert(::Type{Hash}, ptr::RExtPtr)
    Hash(Pair(ptr.tag.displayname, ptr.protected))
end

##############################################################################
##
## Conversion of intermediate R objects into DataArray and DataFrame objects
##
##############################################################################

namask(rl::RLogicalVector) = bitpack(rl.data .== R_NA_INT32)
namask(ri::RIntegerVector) = bitpack(ri.data .== R_NA_INT32)
namask(rn::RNumericVector) = bitpack([rn.data[i] === R_NA_FLOAT64 for i in 1:length(rn.data)])
namask(rc::RComplexVector) = bitpack([rc.data[i].re === R_NA_FLOAT64 ||
                                      rc.data[i].im === R_NA_FLOAT64 for i in 1:length(rc.data)])
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

function sexp2julia(rl::RSEXPREC)
    # TODO warning that converter is missing
    return nothing
end

function sexp2julia(rv::RVEC)
    nas = namask(rv)
    hasna = any(nas)
    if hasnames(rv)
        # if data has no NA, convert to simple Vector
        if hasna DictoVec( DataArray(rv.data, nas), names(rv) )
        else DictoVec( rv.data, names(rv) )
        end
    else
        # no, names, the result is just a vector
        if hasna DataArray(rv.data, nas)
        else rv.data
        end
    end
end

function sexp2julia(rl::RList)
    if isdataframe(rl)
        DataFrame(map(data, rl.data),
                  Symbol[identifier(x) for x in names(rl)])
    else
        DictoVec{Vector{Any}}( map(sexp2julia, rl.data), names(rl) )
    end
end
