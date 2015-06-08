function name2index( names::Vector{RString} )
    n2i = Dict{RString,Int64}()
    i2n = Dict{Int64,RString}()
    for i in eachindex(names)
        if names[i] != ""
            n2i[names[i]] = i
            i2n[i] = names[i]
        end
    end
    n2i, i2n
end

# Dictionary or vector
type DictoVec{V}
    data::V
    name2index::Dict{RString,Int64}
    index2name::Dict{Int64,RString}

    function DictoVec( data::V, names::Vector{RString} )
        n2i, i2n = name2index(names)
        new( data, n2i, i2n )
    end
end

Base.haskey{K<:String}(dict::DictoVec{K}, key::K) = haskey( dict.index, key )

function Base.setindex!(dict::DictoVec, value, key::RString)
    ix = get( dict.name2index, key, length(data)+1 )
    dict.name2index[key] = ix
    dict.index2name[ix] = key
    setindex!( dict.data, value, ix)
end

function Base.setindex!(dict::DictoVec, value, index::Int64)
    setindex!(dict.data, value, index)
end

Base.getindex(dict::DictoVec, index::Int64) = getindex(dict.data, index)

function Base.getindex(dict::DictoVec, key)
    ix = get(dict.name2index, key, 0)
    if ix > 0
        return getindex(dict.data, ix)
    else
        throw(KeyError(key))
    end
end

Base.get(dict::DictoVec, index::Int64, default) = get( dict.data, index, default )

function Base.get(dict::DictoVec, key, default)
    ix = get( dict.name2index, key, 0 )
    return ix > 0 ? dict.data[ix] : default
end

Base.get(f::Function, dict::DictoVec, index::Int64) = get(f, dict.data, index)

function Base.get(f::Function, dict::DictoVec, key)
    ix = get( dict.name2index, key, 0 )
    return ix > 0 ? dict.data[ix] : f()
end

function Base.keys(dict::DictoVec)
    return keys(dict.name2index)
end

function Base.values(dict::DictoVec)
    return eachindex(dict.data)
end

function Base.show{V}(io::IO, dict::DictoVec{V})
    if isempty(dict.name2index)
        # no keys
        show(dict.data)
    else
        first = true
        print(io, "DictoVec(")
        for i in eachindex(dict.data)
            first || print(io, ',')
            first = false
            k = get( dict.index2name, i, "" )
            if key != ""
                show(io, k)
                print(io, "=>")
            end
            show(io, dict.data[i])
            n+=1
            # limit && n >= 10 && (print(io, "…"); break)
        end
        print(io, ")")
    end
end

Base.show{V}(dict::DictoVec{V}) = Base.show(STDOUT, dict)
