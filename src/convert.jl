# converters from selected RSEXPREC to Hash
# They are used to translate SEXPREC attributes into Hash

function Base.convert(::Type{Hash}, pl::RPairList)
    res = Hash()
    for i in eachindex(pl.items)
        @inbounds setindex!(res, pl.items[i], pl.tags[i])
    end
    res
end

##############################################################################
##
## Conversion of intermediate R objects into Vector{T} and DataFrame objects
##
##############################################################################

isna(x::Int32) = x == R_NA_INT32
isna(x::Float64) = isna_float64(reinterpret(UInt64, x))
# if re or im is NA, the whole complex number is NA
isna(x::Complex128) = isna(real(x)) || isna(imag(x))

# convert R vector into Vector holding elements of type T
# if force_missing is true, the result is always Vector{Union{T,Missing}},
# otherwise it's Vector{T} if `rv` doesn't contain NAs
function jlvec(::Type{T}, rv::RVEC, force_missing::Bool=true) where T
    anyna = any(isna, rv.data)
    if force_missing || anyna
        res = convert(Vector{Union{T,Missing}}, rv.data)
        if anyna
            @inbounds for (i,x) in enumerate(rv.data)
                isna(x) && (res[i] = missing)
            end
        end
        return res
    else
        return convert(Vector{T}, rv.data)
    end
end

# convert R nullable vector (has an explicit NA mask) into Vector{T[?]}
function jlvec(::Type{T}, rv::RNullableVector{R}, force_missing::Bool=true) where {T, R}
    anyna = any(rv.na)
    if force_missing || anyna
        res = convert(Vector{Union{T,Missing}}, rv.data)
        anyna && @inbounds res[rv.na] = missing
        return res
    else
        return convert(Vector{T}, rv.data)
    end
end

# convert R vector into Vector of appropriate type
jlvec(rv::RVEC, force_missing::Bool=true) = jlvec(eltype(rv.data), rv, force_missing)

# convert R logical vector (uses Int32 to store values) into Vector{Bool[?]}
function jlvec(rl::RLogicalVector, force_missing::Bool=true)
    anyna = any(isna, rl.data)
    if force_missing || anyna
        return Union{Bool,Missing}[ifelse(isna(x), missing, x != 0) for x in rl.data]
    else
        return Bool[x != 0 for x in rl.data]
    end
end

# kernel method that converts Vector{Int32} into Vector{R} replacing R_NA_INT32 with 0
# it's assumed that v fits into R
na2zero(::Type{R}, v::Vector{Int32}) where R =
    [ifelse(!isna(x), x % R, zero(R)) for x in v]

# convert to CategoricalVector{String[?]} if `ri` is a factor,
# or to Vector{Int32[?]} otherwise
function jlvec(ri::RIntegerVector, force_missing::Bool=true)
    isfactor(ri) || return jlvec(eltype(ri.data), ri, force_missing)

    rlevels = getattr(ri, "levels", emptystrvec)
    sz = length(rlevels)
    REFTYPE = sz <= typemax(UInt8)  ? UInt8 :
              sz <= typemax(UInt16) ? UInt16 :
              sz <= typemax(UInt32) ? UInt32 :
                                      UInt64
    # FIXME set ordered flag
    refs = na2zero(REFTYPE, ri.data)
    anyna = any(iszero, refs)
    pool = CategoricalPool{String, REFTYPE}(rlevels)
    if force_missing || anyna
        return CategoricalArray{Union{String, Missing}, 1}(refs, pool)
    else
        return CategoricalArray{String, 1}(refs, pool)
    end
end

function sexp2julia(rex::RSEXPREC)
    warn("Conversion of $(typeof(rex)) to Julia is not implemented")
    return nothing
end

function sexp2julia(rv::RVEC)
    # TODO dimnames?
    # FIXME add force_missing option to control whether always convert to Union{T, Missing}
    jv = jlvec(rv, false)
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
        # FIXME add force_missing option to control whether always convert to Union{T, Missing}
        DataFrame(Any[jlvec(col, false) for col in rl.data], identifier.(names(rl)))
    elseif hasnames(rl)
        DictoVec(Any[sexp2julia(item) for item in rl.data], names(rl))
    else
        # FIXME return DictoVec if forceDictoVec is on
        map(sexp2julia, rl.data)
    end
end
