# converters from selected RSEXPREC to Hash
# They are used to translate SEXPREC attributes into Hash

import TimeZones: unix2zdt
import DataArrays: @data

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
    refs = na2zero(REFTYPE, ri.data)
    anyna = any(iszero, refs)
    pool = CategoricalPool{String, REFTYPE}(rlevels, inherits(ri, "ordered"))
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
    if class(rv) == R_Date_Class
        return date2julia(rv)
    elseif class(rv) == R_POSIXct_Class
        return datetime2julia(rv)
    elseif hasnames(rv)
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

function date2julia(rv)
    @assert class(rv) == R_Date_Class
    epoch_conv = 719528 # Dates.date2epochdays(Date("1970-01-01"))
    nas = isnan.(rv.data)
    if any(nas)
        dates = @data([isna ? missing : Dates.epochdays2date(dtfloat + epoch_conv)
                      for (isna, dtfloat) in zip(nas, rv.data)])
    else
        dates = Dates.epochdays2date.(rv.data .+ epoch_conv)
    end
    if hasnames(rv)
        dates = DictoVec(dates, names(rv))
    end
    return length(dates) == 1 & !hasnames(rv) ? dates[1] : dates
end

# return tuple is true/false status of whether tzattr was successfully interpreted
# then the tz itself. when not successfully interpreted, tz defaults to UTC
function gettz(tzattr)
    try
        return true, TimeZone(tzattr)
    catch ArgumentError
        warn("Could not determine timezone of '$(tzattr)', treating as if UTC.")
        return false, tz"UTC"
    end
end

function unix2zdt(seconds::Real; tz::TimeZone=tz"UTC")
    ZonedDateTime(Dates.unix2datetime(seconds), tz, from_utc=true)
end

function datetime2julia(rv)
    @assert class(rv) == R_POSIXct_Class
    tzattr = getattr(rv, "tzone", ["UTC"])[1]
    tzattr = tzattr == "" ? "UTC" : tzattr # R will store a blank for tzone
    goodtz, tz = gettz(tzattr)
    nas = isnan.(rv.data)
    if any(nas)
        datetimes = @data([isna ? missing : unix2zdt(dtfloat, tz=tz)
                           for (isna, dtfloat) in zip(nas, rv.data)])
    else
        datetimes =  unix2zdt.(rv.data, tz=tz)
    end
    if hasnames(rv)
        datetimes = DictoVec(datetimes, names(rv))
    end
    return length(datetimes) == 1 & !hasnames(rv) ? datetimes[1] : datetimes
end

