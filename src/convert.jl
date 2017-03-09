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
## Conversion of intermediate R objects into NullableArray and DataTable objects
##
##############################################################################

namask(ri::RVector{Int32}) = [i == R_NA_INT32 for i in ri.data]
namask(rn::RNumericVector) = map(isna_float64, reinterpret(UInt64, rn.data))
# if re or im is NA, the whole complex number is NA
# FIXME avoid temporary Vector{Bool}
namask(rc::RComplexVector) = [isna_float64(v.re) || isna_float64(v.im) for v in reinterpret(Complex{UInt64}, rc.data)]
namask(rv::RNullableVector) = rv.na

function _julia_vector{T}(::Type{T}, rv::RVEC, force_nullable::Bool)
    na_mask = namask(rv)
    (force_nullable || any(na_mask)) ? NullableArray(convert(Vector{T}, rv.data), na_mask) : rv.data
end

# convert R vector into either NullableArray
# or Array if force_nullable=false and there are no NAs
julia_vector(rv::RVEC, force_nullable::Bool) = _julia_vector(eltype(rv.data), rv, force_nullable)

function julia_vector(rl::RLogicalVector, force_nullable::Bool)
    v = Bool[flag != zero(eltype(rl.data)) for flag in rl.data]
    na_mask = namask(rl)
    (force_nullable || any(na_mask)) ? NullableArray(v, na_mask) : v
end

# converts Vector{Int32} into Vector{R} replacing R_NA_INT32 with 0
na2zero{R}(::Type{R}, v::Vector{Int32}) = [x != R_NA_INT32 ? R(x) : zero(R) for x in v]

# convert to [Nullable]CategoricalArray{String} if `ri`is a factor,
# or to [Nullable]Array{Int32} otherwise
function julia_vector(ri::RIntegerVector, force_nullable::Bool)
    !isfactor(ri) && return _julia_vector(eltype(ri.data), ri, force_nullable) # not a factor

    # convert factor into [Nullable]CategoricalArray
    rlevels = getattr(ri, "levels", emptystrvec)
    sz = length(rlevels)
    REFTYPE = sz <= typemax(UInt8)  ? UInt8 :
              sz <= typemax(UInt16) ? UInt16 :
              sz <= typemax(UInt32) ? UInt32 :
                                      UInt64
    # FIXME set ordered flag
    refs = na2zero(REFTYPE, ri.data)
    pool = CategoricalPool{String, REFTYPE}(rlevels)
    (force_nullable || (findfirst(refs, zero(REFTYPE)) > 0)) ?
        NullableCategoricalArray{String, 1, REFTYPE}(refs, pool) :
        CategoricalArray{String, 1, REFTYPE}(refs, pool)
end

function sexp2julia(rex::RSEXPREC)
    warn("Conversion of $(typeof(rex)) to Julia is not implemented")
    return nothing
end

function sexp2julia(rv::RVEC)
    # TODO dimnames?
    # FIXME forceNullable option to always convert to NullableArray
    jv = julia_vector(rv, false)
    if hasnames(rv)
        # if data has no NA, convert to simple Vector
        return DictoVec(jv, names(rv))
    else
        hasdims = hasdim(rv)
        if !hasdims && length(rv.data)==1
            # scalar
            return jv[1]
        elseif !hasdims
            # vectors
            return jv
        else
            # matrices and so on
            dims = tuple(convert(Vector{Int}, getattr(rv, "dim"))...)
            return reshape(jv, dims)
        end
    end
end

function sexp2julia(rl::RList)
    if isdataframe(rl)
        # FIXME forceNullable option to always convert to NullableArray
        DataTable(Any[julia_vector(col, true) for col in rl.data], map(identifier, names(rl)))
    elseif hasnames(rl)
        DictoVec(Any[sexp2julia(item) for item in rl.data], names(rl))
    else
        # FIXME return DictoVec if forceDictoVec is on
        map(sexp2julia, rl.data)
    end
end
