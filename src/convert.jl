# converters from selected RSEXPREC to Hash
# They are used to translate SEXPREC attributes into Hash

using Dates

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
isna(x::ComplexF64) = isna(real(x)) || isna(imag(x))

# convert R vector into Vector holding elements of type T
# if force_missing is true, the result is always Vector{Union{T,Missing}},
# otherwise it's Vector{T} if `rv` doesn't contain NAs
function jlvec(::Type{T}, rv::RVEC, force_missing::Bool=true) where T <: Number
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
        anyna && @inbounds res[rv.na] .= missing
        return res
    else
        return convert(Vector{T}, rv.data)
    end
end

# convert R vector into Vector of appropriate type
function jlvec(rv::RVEC, force_missing::Bool=true)
    if inherits(rv, R_Date_Class)
        return jlvec(Dates.Date, rv, force_missing)
    elseif inherits(rv, R_POSIXct_Class)
        return jlvec(ZonedDateTime, rv, force_missing)
    else
        return jlvec(isconcretetype(eltype(rv.data)) ? eltype(rv.data) : Any, rv, force_missing)
    end
end

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
# to Dates.Date is it's a vector of dates and
# to Vector{Int32[?]} otherwise
function jlvec(ri::RIntegerVector, force_missing::Bool=true)
    if isfactor(ri)
        return jlvec(CategoricalArray, ri, force_missing)
    elseif inherits(ri, R_Date_Class)
        return jlvec(Dates.Date, ri, force_missing)
    else
        return jlvec(eltype(ri.data), ri, force_missing)
    end
end

# convert R factor to CategoricalArray
function jlvec(::Type{CategoricalArray}, ri::RVEC, force_missing::Bool=true)
    @assert isfactor(ri)

    rlevels0 = getattr(ri, "levels")
    sz0 = length(rlevels0)
    # CategoricalArrays#v0.8 does not allow duplicate levels
    rlevels = unique(rlevels0)
    sz = length(rlevels)
    hasduplicates = sz0 != sz

    REFTYPE = sz0 <= typemax(UInt8)  ? UInt8 :
              sz0 <= typemax(UInt16) ? UInt16 :
              sz0 <= typemax(UInt32) ? UInt32 :
                                      UInt64
    refs = na2zero(REFTYPE, ri.data)

    if hasduplicates
        # map refs with dups to unique refs
        ref_map = REFTYPE.(indexin(rlevels0, rlevels))
        @inbounds for i in eachindex(refs)
            ref = refs[i]
            refs[i] = ref == 0 ? 0 : ref_map[ref]
        end
        @warn "Dropped duplicate factor levels"
    end

    anyna = any(iszero, refs)
    pool = CategoricalPool{String, REFTYPE}(rlevels, inherits(ri, "ordered"))
    if force_missing || anyna
        return CategoricalArray{Union{String, Missing}, 1}(refs, pool)
    else
        return CategoricalArray{String, 1}(refs, pool)
    end
end

# convert R Date to Dates.Date
function jlvec(::Type{Dates.Date}, rv::RVEC, force_missing::Bool=true)
    @assert inherits(rv, R_Date_Class)
    nas = isnan.(rv.data)
    if force_missing || any(nas)
        dates = Union{Dates.Date, Missing}[isna ? missing : rdays2date(dtfloat)
                 for (isna, dtfloat) in zip(nas, rv.data)]
    else
        dates = rdays2date.(rv.data)
    end
    return dates
end

# convert R POSIXct to ZonedDateTime
function jlvec(::Type{ZonedDateTime}, rv::RVEC, force_missing::Bool=true)
    @assert class(rv) == R_POSIXct_Class
    tz, validtz = getjuliatz(rv)
    nas = isnan.(rv.data)
    if force_missing || any(nas)
        datetimes = Union{ZonedDateTime, Missing}[isna ? missing : _unix2zdt(dtfloat, tz=tz)
                     for (isna, dtfloat) in zip(nas, rv.data)]
    else
        datetimes = _unix2zdt.(rv.data, tz=tz)
    end
    return datetimes
end

function simplify_eltype(v::AbstractVector)
    isconcretetype(eltype(v)) && return eltype(v)

    eltypes = Set{DataType}()
    eltyp = Union{}
    try
        for x in v
            xtyp = typeof(x)
            if !(xtyp in eltypes)
                # promote only if arrays have the same eltype, otherwise return Any
                if (eltyp === Union{}) ||
                   (nonmissingtype(xtyp) === nonmissingtype(eltyp)) ||
                   (xtyp <: AbstractArray && eltyp <: AbstractArray &&
                    nonmissingtype(eltype(xtyp)) === nonmissingtype(eltype(eltyp)))
                    eltyp = promote_type(eltyp, xtyp)
                else
                    return Any
                end
                if !isconcretetype(eltyp) || (eltyp === Any)
                    return Any
                end
                push!(eltypes, xtyp)
            end
        end
    catch e # missing promotion rule
        return Any
    end
    return eltyp
end

# generic vector conversion
function jlvec(::Type{T}, rv::RVEC, force_missing::Bool=true) where T
    res = sexp2julia.(rv.data)
    if !isconcretetype(eltype(res))
        return convert(Vector{simplify_eltype(res)}, res)
    else
        return res
    end
end

function sexp2julia(rex::RSEXPREC)
    @warn "Conversion of $(typeof(rex)) to Julia is not implemented" maxlog=1
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
        DataFrame(Any[isa(col, RAltRep) ? sexp2julia(col) : jlvec(col, false) for col in rl.data],
                  identifier.(names(rl)), makeunique=true)
    elseif hasnames(rl)
        DictoVec(jlvec(Any, rl), names(rl))
    else
        # FIXME return DictoVec if forceDictoVec is on
        jlvec(Any, rl)
    end
end

function sexp2julia(ar::RAltRep)
    if iswrapped(ar)
        return sexp2julia(unwrap(ar))
    else
        # TODO support compact_intseq and compact_realseq AltRep
        @warn unsupported_altrep_message(ar)
        return nothing
    end
end

function rdays2date(days::Real)
    epoch_conv = 719528 # Dates.date2epochdays(Date("1970-01-01"))
    Dates.epochdays2date(days + epoch_conv)
end

# gets R timezone from the data attribute and converts it to TimeZones.TimeZone
# see r2juliatz()
function getjuliatz(rv::RVEC, deftz=tz"UTC")
    tzattr = getattr(rv, "tzone", [""])[1]
    if tzattr == ""
        return deftz, true # R will store a blank for tzone
    else
        return r2juliatz(tzattr, deftz)
    end
end

# converts R timezone code to TimeZones.TimeZone
# returns a tuple:
#  - timezone (or `deftz` if `rtz` is not recognized as a valid time zone)
#  - boolean flag: true if `rtz` is not recognized, false otherwise
function r2juliatz(rtz::AbstractString, deftz=tz"UTC")
    valid = istimezone(rtz)
    if !valid
        @warn "Could not determine the timezone of '$(rtz)', treating as '$deftz'" maxlog=1
        return deftz, false
    else
        return TimeZone(rtz), true
    end
end

# version with user-specified tz (unix2zdt(seconds) is fixed to tz"UTZ")
_unix2zdt(seconds::Real; tz::TimeZone=tz"UTC") =
    ZonedDateTime(Dates.unix2datetime(seconds), tz, from_utc=true)
