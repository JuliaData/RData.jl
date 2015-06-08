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

namask(rl::RLogical) = bitpack(rl.data .== R_NA_INT32)
namask(ri::RInteger) = bitpack(ri.data .== R_NA_INT32)
namask(rn::RNumeric) = bitpack([rn.data[i] === R_NA_FLOAT64 for i in 1:length(rn.data)])
namask(rc::RComplex) = bitpack([rc.data[i].re === R_NA_FLOAT64 ||
                                rc.data[i].im === R_NA_FLOAT64 for i in 1:length(rc.data)])
namask(rv::RNullableVector) = rv.na

DataArrays.data(rv::RVEC) = DataArray(rv.data, namask(rv))

function DataArrays.data(ri::RInteger)
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

function Base.convert(::Type{DataFrame}, rl::RList)
    DataFrame(map(data, rl.data),
              Symbol[identifier(x) for x in names(rl)])
end
