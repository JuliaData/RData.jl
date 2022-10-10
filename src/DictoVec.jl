"""
Container that mimics R vector behaviour.
Elements could be accessed either by indices as a normal vector,
or (optionally) by string keys as a dictionary.
"""
struct DictoVec{T}
    data::Vector{T}
    name2index::Dict{RString, Int}
    index2name::Vector{Union{RString, Nothing}}

    function DictoVec(data::AbstractVector{T}, names::AbstractVector{<:AbstractString} = Vector{RString}()) where T
        if !isempty(names) && length(data) != length(names)
            throw(DimensionMismatch("Lengths of data ($(length(data))) and element names ($(length(names))) differ"))
        end
        n2i = Dict{RString, Int}()
        i2n = fill!(similar(data, Union{RString, Nothing}), nothing)
        @inbounds for (i, k) in enumerate(names)
            if k != "" && k !== nothing
                n2i[k] = i
                i2n[i] = k
            else
                i2n[i] = nothing
            end
        end
        new{T}(data, n2i, i2n)
    end
end

Base.:(==)(dict1::DictoVec, dict2::DictoVec) =
    dict1.name2index == dict2.name2index && dict1.data == dict2.data
Base.isequal(dict1::DictoVec, dict2::DictoVec) =
    isequal(dict1.name2index, dict2.name2index) && isequal(dict1.data, dict2.data)

const hash_dictovec_seed = UInt === UInt64 ? 0xe00ac4bbcfc2fa07 : 0x57f3f900
Base.hash(dict::DictoVec, h::UInt) =
    hash(dict.name2index, hash(dict.data, h + hash_dictovec_seed))

Base.eltype(::Type{DictoVec{T}}) where T = T
Base.eltype(dict::DictoVec) = eltype(typeof(dict))
Base.length(dict::DictoVec) = length(dict.data)
Base.isempty(dict::DictoVec) = isempty(dict.data)

# key-based indexing
Base.haskey(dict::DictoVec, key) = haskey(dict.name2index, key)

function Base.setindex!(dict::DictoVec, value, key)
    ix = get(dict.name2index, key, 0)
    if ix > 0 # existing key
        setindex!(dict.data, value, ix)
    else # new key
        _key = convert(keytype(dict.name2index), key) # throws if key is not compatible
        push!(dict.data, value) # first try to add value (throws if it's not compatible)
        push!(dict.index2name, _key)
        dict.name2index[_key] = length(dict.data)
    end
end

function Base.getindex(dict::DictoVec, key)
    ix = get(dict.name2index, key, 0)
    if ix > 0
        return getindex(dict.data, ix)
    else
        throw(KeyError(key))
    end
end

# integer-based indexing (overrides key-based indexing)
Base.setindex!(dict::DictoVec, value, index::Integer) =
    setindex!(dict.data, value, index)
Base.setindex!(dict::DictoVec, values, indices::AbstractVector{<:Integer}) =
    setindex!(dict.data, values, indices)

Base.getindex(dict::DictoVec, index::Integer) = getindex(dict.data, index)
Base.getindex(dict::DictoVec, indices::AbstractVector{<:Integer}) = getindex(dict.data, indices)

Base.get(dict::DictoVec, index::Integer, default) = get(dict.data, index, default)
Base.get(f::Function, dict::DictoVec, index::Integer) = index ∈ eachindex(dict.data) ? dict.data[index] : f()

function Base.get(dict::DictoVec, key, default)
    ix = get(dict.name2index, key, 0)
    return ix > 0 ? dict.data[ix] : default
end

function Base.get(f::Function, dict::DictoVec, key)
    ix = get(dict.name2index, key, 0)
    return get(f, dict, ix)
end

function Base.delete!(dict::DictoVec, key)
    ix = pop!(dict.name2index, key, 0)
    if ix > 0
        deleteat!(dict.data, ix)
        deleteat!(dict.index2name, ix)
        if ix <= length(dict)
            # update indices
            for (k, oldix) in pairs(dict.name2index)
                if oldix > ix
                    dict.name2index[k] = oldix - 1
                end
            end
        end
    end
    return dict
end

Base.keys(dict::DictoVec) = keys(dict.name2index)

Base.values(dict::DictoVec) = dict.data

function Base.show(io::IO, dict::DictoVec)
    first = true
    print(io, typeof(dict), "(")
    n = 0
    for i in eachindex(dict.data)
        first || print(io, ',')
        first = false
        k = dict.index2name[i]
        if k !== nothing
            show(io, k)
            print(io, "=>")
        end
        show(io, dict.data[i])
        n += 1
        # limit && n >= 10 && (print(io, "…"); break)
    end
    print(io, ")")
end

function Base.convert(::Type{Dict{RString,Any}}, dv::DictoVec)
    res = Dict{RString,Any}()
    # elements that are only referenced by the index would not be in the result
    for (k, v) in dv.name2index
        res[k] = dv.data[v]
    end
    return res
end
