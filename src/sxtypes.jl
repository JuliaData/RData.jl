##############################################################################
##
## Julia types encapsulating various types of R SEXPRECs
##
##############################################################################


abstract RSEXPREC{S}             # Basic R object - symbolic expression

type RSymbol <: RSEXPREC{SYMSXP} # Not quite the same as a Julia symbol
    displayname::RString
end

abstract ROBJ{S} <: RSEXPREC{S}  # R object that can have attributes

abstract RVEC{T, S} <: ROBJ{S}   # abstract R vector (actual storage implementation may differ)

type RVector{T, S} <: RVEC{T, S} # R vector object
    data::Vector{T}
    attr::Hash                   # collection of R object attributes

    RVector(v::Vector{T} = T[], attr::Hash = Hash()) = new(v, attr)
end

typealias RLogicalVector RVector{Int32, LGLSXP}
typealias RIntegerVector RVector{Int32, INTSXP}
typealias RNumericVector RVector{Float64, REALSXP}
typealias RComplexVector RVector{Complex128, CPLXSXP}

type RNullableVector{T, S} <: RVEC{T, S} # R vector object with explicit NA values
    data::Vector{T}
    na::BitVector                # mask of NA elements
    attr::Hash                   # collection of R object attributes
end

typealias RStringVector RNullableVector{RString,STRSXP}
typealias RList RVector{RSEXPREC,VECSXP}  # "list" in R == Julia cell array

# Representation of R's paired list-like structures
# (LISTSXP, LANGSXP)
# Unlike R that represents it as singly-linked list,
# uses vector representation
type RPairList <: ROBJ{LISTSXP}
    items::Vector{RSEXPREC}
    tags::Vector{RString}
    attr::Hash

    RPairList( attr::Hash = Hash() ) = new( RSEXPREC[], RString[], attr )
end

function Base.push!( pl::RPairList, item::RSEXPREC, tag::RString )
    push!( pl.tags, tag )
    push!( pl.items, item )
end

type RClosure <: ROBJ{CLOSXP}
    formals
    body
    env
    attr::Hash

    RClosure( attr::Hash = Hash() ) = new( nothing, nothing, nothing, attr )
end

type RBuiltin <: RSEXPREC{BUILTINSXP}
    internal_function::RString
end

type RPromise <: ROBJ{PROMSXP}
    value
    expr
    env
    attr::Hash

    RPromise( attr::Hash = Hash() ) = new( nothing, nothing, nothing, attr )
end

type REnvironment <: ROBJ{ENVSXP}
    enclosed
    frame
    hashtab
    attr::Hash

    REnvironment() = new( nothing, nothing, nothing, Hash() )
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

    RExtPtr() = new( nothing, nothing, Hash() )
end

type RBytecode <: ROBJ{BCODESXP}
    attr::Hash
    tag
    car
    cdr
    RBytecode( code = nothing, consts = nothing, attr::Hash = Hash() ) = new( attr, nothing, code, consts )
end

type RPackage <: RSEXPREC{PACKAGESXP}
    name::Vector{RString}
end

type RNamespace <: RSEXPREC{NAMESPACESXP}
    name::Vector{RString}
end

# R objects without body (empty environments, missing args etc)
type RDummy{S} <: RSEXPREC{S}
end

##############################################################################
##
## Utilities for working with basic properties of R objects:
##    attributes, class inheritance, etc
##
##############################################################################

const emptystrvec = RString[]

hasattr(ro::ROBJ, attrnm) = haskey(ro.attr, attrnm)
hasnames(ro::ROBJ) = hasattr(ro, "names")
hasdim(ro::ROBJ) = hasattr(ro, "dim")
hasdimnames(ro::ROBJ) = hasattr(ro, "dimnames")
getattr(ro::ROBJ, attrnm) = getindex( ro.attr, attrnm ).data
getattr(ro::ROBJ, attrnm, default) = hasattr( ro, attrnm ) ? getindex( ro.attr, attrnm ).data : default

Base.names(ro::ROBJ) = getattr(ro, "names")

class(ro::ROBJ) = getattr(ro, "class", emptystrvec)
class(x) = emptystrvec
inherits(x, clnm) = any(class(x) .== clnm)

isdataframe(rl::RList) = inherits(rl, "data.frame")
isfactor(ri::RIntegerVector) = inherits(ri, "factor")

Base.length(rl::RVEC) = length(rl.data)
Base.size(rv::RVEC) = length(rv.data)
Base.size(rl::RList) = isdataframe(rl) ? (length(rl.data[1]), length(rl.data)) : length(rl.data)

row_names(ro::ROBJ) = getattr(ro, "row.names", emptystrvec)
