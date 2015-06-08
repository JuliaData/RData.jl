##############################################################################
##
## Julia types encapsulating various types of R SEXPRECs
##
##############################################################################


abstract RSEXPREC{S}             # Basic R object - symbolic expression

type RSymbol <: RSEXPREC{SYMSXP} # Not quite the same as a Julia symbol
    displayname::String
end

abstract ROBJ{S} <: RSEXPREC{S}  # R object that can have attributes

abstract RVEC{T, S} <: ROBJ{S}   # abstract R vector (actual storage implementation may differ)

type RVector{T, S} <: RVEC{T, S} # R vector object
    data::Vector{T}
    attr::Hash                   # collection of R object attributes

    RVector(v::Vector{T} = T[], attr::Hash = Hash()) = new(v, attr)
end

typealias RLogical RVector{Int32, LGLSXP}
typealias RInteger RVector{Int32, INTSXP}
typealias RNumeric RVector{Float64, REALSXP}
typealias RComplex RVector{Complex128, CPLXSXP}

type RNullableVector{T, S} <: RVEC{T, S} # R vector object with explicit NA values
    data::Vector{T}
    na::BitVector               # mask of NA elements
    attr::Hash                  # collection of R object attributes
end

typealias RString RNullableVector{String,STRSXP}
typealias RList RVector{Any,VECSXP}  # "list" in R == Julia cell array

# Representation of R's paired list-like structures
# (LISTSXP, LANGSXP)
# Unlike R that represents it as singly-linked list,
# uses vector representation
type RPairList <: ROBJ{LISTSXP}
    items::Vector{Any}
    tags::Vector{String}
    attr::Hash

    RPairList( attr::Hash = Hash() ) = new( Any[], String[], attr )
end

function Base.push!( pl::RPairList, item, tag::String )
    push!( pl.tags, tag )
    push!( pl.items, item )
end

function Base.push!( pl::RPairList, item )
    push!( pl, null, item )
end

type RClosure <: ROBJ{CLOSXP}
    formals
    body
    env
    attr::Hash

    RClosure( attr::Hash = Hash() ) = new( null, null, null, attr )
end

type RPromise <: ROBJ{PROMSXP}
    value
    expr
    env
    attr::Hash

    RPromise( attr::Hash = Hash() ) = new( null, null, null, attr )
end

type REnvironment <: ROBJ{ENVSXP}
    enclosed
    frame
    hashtab
    attr::Hash

    REnvironment() = new( null, null, null, Hash() )
end

type RRaw <: ROBJ{RAWSXP}
    data
    attr::Hash
end

type RS4Obj <: ROBJ{S4SXP}
    attr::Hash
end

type RExtPtr <: ROBJ{EXTPTRSXP}
    protected
    tag
    attr::Hash

    RExtPtr() = new( null, null, Hash() )
end

type RBytecode <: ROBJ{BCODESXP}
    attr::Hash
    tag
    car
    cdr
    RBytecode( code = null, consts = null, attr::Hash = Hash() ) = new( attr, null, code, consts )
end

type RPackage <: RSEXPREC{PACKAGESXP}
    name::Vector{String}
end

type RNamespace <: RSEXPREC{NAMESPACESXP}
    name::Vector{String}
end

##############################################################################
##
## Utilities for working with basic properties of R objects:
##    attributes, class inheritance, etc
##
##############################################################################

const emptystrvec = Array(String,0)

getattr{T}(ro::ROBJ, attrnm::String, default::T) = haskey(ro.attr, attrnm) ? ro.attr[attrnm].data : default;

Base.names(ro::ROBJ) = getattr(ro, "names", emptystrvec)

class(ro::ROBJ) = getattr(ro, "class", emptystrvec)
class(x) = emptystrvec
inherits(x, clnm::String) = any(class(x) .== clnm)

isdataframe(rl::RList) = inherits(rl, "data.frame")
isfactor(ri::RInteger) = inherits(ri, "factor")

Base.length(rl::RVEC) = length(rl.data)
Base.size(rv::RVEC) = length(rv.data)
Base.size(rl::RList) = isdataframe(rl) ? (length(rl.data[1]), length(rl.data)) : length(rl.data)

row_names(ro::ROBJ) = getattr(ro, "row.names", emptystrvec)
