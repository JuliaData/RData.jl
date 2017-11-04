function name2index(names::Vector{RString})
    n2i = Dict{RString,Int64}()
    i2n = Dict{Int64,RString}()
    @inbounds for (i,k) in enumerate(names)
        if k != ""
            n2i[k] = i
            i2n[i] = k
        end
    end
    n2i, i2n
end

"""
Container that mimics R vector behaviour.
Elements could be accessed either by indices as a normal vector,
or (optionally) by string keys as a dictionary.
"""
struct DictoVec{T}
    data::T
    name2index::Dict{RString, Int}
    index2name::Dict{Int, RString}

    function (::Type{DictoVec})(data::T, names::Vector{RString} = Vector{RString}()) where T
        n2i, i2n = name2index(names)
        new{T}(data, n2i, i2n)
    end
end

Base.length(dict::DictoVec) = length(dict.data)
Base.isempty(dict::DictoVec) = isempty(dict.data)

Base.haskey(dict::DictoVec, key) = haskey(dict.name2index, key)

function Base.setindex!(dict::DictoVec, value, key)
    ix = get(dict.name2index, key, 0)
    if ix > 0
      setindex!(dict.data, value, ix)
    else
      dict.name2index[key] = length(dict.data)+1
      dict.index2name[ix] = key
      push!(dict.data, value)
    end
end

function Base.setindex!(dict::DictoVec, value, index::Int64)
    setindex!(dict.data, value, index)
end

Base.getindex(dict::DictoVec, index::Int) = getindex(dict.data, index)

function Base.getindex(dict::DictoVec, key)
    ix = get(dict.name2index, key, 0)
    if ix > 0
        return getindex(dict.data, ix)
    else
        throw(KeyError(key))
    end
end

Base.get(dict::DictoVec, index::Int, default) = get(dict.data, index, default)

function Base.get(dict::DictoVec, key, default)
    ix = get(dict.name2index, key, 0)
    return ix > 0 ? dict.data[ix] : default
end

Base.get(f::Function, dict::DictoVec, index::Int) = get(f, dict.data, index)

function Base.get(f::Function, dict::DictoVec, key)
    ix = get(dict.name2index, key, 0)
    return ix > 0 ? dict.data[ix] : f()
end

function Base.keys(dict::DictoVec)
    return keys(dict.name2index)
end

function Base.values(dict::DictoVec)
    return dict.data
end

function Base.show(io::IO, dict::DictoVec)
    if isempty(dict.name2index)
        # no keys
        show(dict.data)
    else
        first = true
        print(io, "DictoVec(")
        n = 0
        for i in eachindex(dict.data)
            first || print(io, ',')
            first = false
            k = get(dict.index2name, i, "")
            if k != ""
                show(io, k)
                print(io, "=>")
            end
            show(io, dict.data[i])
            n += 1
            # limit && n >= 10 && (print(io, "…"); break)
        end
        print(io, ")")
    end
end

function Base.convert(::Type{Dict{RString,Any}}, dv::DictoVec)
    res = Dict{RString,Any}()
    for (k,v) in dv.name2index
        res[k] = dv.data[v]
    end
    res
end
