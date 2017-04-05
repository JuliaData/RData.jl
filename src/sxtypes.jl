SXType = UInt8 # stores the type of SEXPREC

##############################################################################
##
## A table of R's SEXPREC tags from RInternals.h
##
##############################################################################

const NILSXP =      0x00 # nil = NULL
const SYMSXP =      0x01 # symbols
const LISTSXP =     0x02 # lists of dotted pairs
const CLOSXP =      0x03 # closures
const ENVSXP =      0x04 # environments
const PROMSXP =     0x05 # promises: [un]evaluated closure arguments
const LANGSXP =     0x06 # language constructs (special lists)
const SPECIALSXP =  0x07 # special forms
const BUILTINSXP =  0x08 # builtin non-special forms
const CHARSXP =     0x09 # "scalar" string type (internal only)
const LGLSXP =      0x0A # logical vectors
# 11 and 12 were factors and ordered factors in the 1990s
const INTSXP =      0x0D # integer vectors
const REALSXP =     0x0E # real variables
const CPLXSXP =     0x0F # complex variables
const STRSXP =      0x10 # string vectors
const DOTSXP =      0x11 # dot-dot-dot object
const ANYSXP = 	    0x12 # make "any" args work. Used in specifying types for symbol registration to mean anything is okay
const VECSXP =      0x13 # generic vectors
const EXPRSXP =     0x14 # expressions vectors
const BCODESXP =    0x15 # byte code
const EXTPTRSXP =   0x16 # external pointer
const WEAKREFSXP =  0x17 # weak reference
const RAWSXP =      0x18 # raw bytes
const S4SXP =       0x19 # S4, non-vector

# used for detecting PROTECT issues in memory.c
const NEWSXP =      0x1E # fresh node creaed in new page
const FREESXP =     0x1F # node released by GC

const FUNSXP =      0x63 # Closure or Builtin or Special

#=
 = Administrative SXP values
 =#
const REFSXP =            0xFF
const NILVALUE_SXP =      0xFE
const GLOBALENV_SXP =     0xFD
const UNBOUNDVALUE_SXP =  0xFC
const MISSINGARG_SXP =    0xFB
const BASENAMESPACE_SXP = 0xFA
const NAMESPACESXP =      0xF9
const PACKAGESXP =        0xF8
const PERSISTSXP =        0xF7
const CLASSREFSXP =       0xF6
const GENERICREFSXP =     0xF5
const BCREPDEF =          0xF4
const BCREPREF =          0xF3
const EMPTYENV_SXP =      0xF2
const BASEENV_SXP =       0xF1
const ATTRLANGSXP =       0xF0
const ATTRLISTSXP =       0xEF

##############################################################################
##
## R objects in the file are preceded by a UInt32 giving the type and
## some flags.  These functions unpack bits in the flags.  The isobj
## bit might be useful for distinguishing an RInteger from a factor or
## an RList from a data.frame.
##
##############################################################################

const RDATag = UInt32

isobj(fl::RDATag) = (fl & 0x00000100) != 0
hasattr(fl::RDATag) = (fl & 0x00000200) != 0
hastag(fl::RDATag) = (fl & 0x00000400) != 0
sxtype(fl::RDATag) = fl % UInt8

##############################################################################
##
## Julia types encapsulating various types of R SEXPRECs
##
##############################################################################

"""
    Base class for RData internal representation of all R types.
    `SEXPREC` stands for S (R predecessor) expression record.
"""
@compat abstract type RSEXPREC{S} end

"""
    R symbol.
    Not quite the same as a Julia symbol.
"""
immutable RSymbol <: RSEXPREC{SYMSXP}
    displayname::RString
end

"""
    Base class for all R types (objects) that can have attributes.
"""
@compat abstract type ROBJ{S} <: RSEXPREC{S} end

"""
   Base class for all R vector-like objects.
"""
@compat abstract type RVEC{T, S} <: ROBJ{S} end

"""
    R vector object.
"""
type RVector{T, S} <: RVEC{T, S}
    data::Vector{T}
    attr::Hash                   # collection of R object attributes

    @compat RVector{T,S}(v::Vector{T} = T[], attr::Hash = Hash()) where {T,S} = new(v, attr)

end

const RLogicalVector = RVector{Int32, LGLSXP}
const RIntegerVector = RVector{Int32, INTSXP}
const RNumericVector = RVector{Float64, REALSXP}
const RComplexVector = RVector{Complex128, CPLXSXP}

"""
    R vector object with explicit NA values.
"""
immutable RNullableVector{T, S} <: RVEC{T, S}
    data::Vector{T}
    na::BitVector                # mask of NA elements
    attr::Hash                   # collection of R object attributes
end

const RStringVector = RNullableVector{RString,STRSXP}
const RList = RVector{RSEXPREC,VECSXP}  # "list" in R == Julia cell array

"""
    Representation of R's paired list-like structures (`LISTSXP`, `LANGSXP`).
    Unlike R which represents these as singly-linked list,
    `RPairList` uses vector representation.
"""
immutable RPairList <: ROBJ{LISTSXP}
    items::Vector{RSEXPREC}
    tags::Vector{RString}
    attr::Hash

    RPairList(attr::Hash = Hash()) = new(RSEXPREC[], RString[], attr)
end

function Base.push!(pl::RPairList, item::RSEXPREC, tag::RString)
    push!(pl.tags, tag)
    push!(pl.items, item)
end

type RClosure <: ROBJ{CLOSXP}
    formals
    body
    env
    attr::Hash

    RClosure(attr::Hash = Hash()) = new(nothing, nothing, nothing, attr)
end

immutable RBuiltin <: RSEXPREC{BUILTINSXP}
    internal_function::RString
end

type RPromise <: ROBJ{PROMSXP}
    value
    expr
    env
    attr::Hash

    RPromise(attr::Hash = Hash()) = new(nothing, nothing, nothing, attr)
end

type REnvironment <: ROBJ{ENVSXP}
    enclosed
    frame
    hashtab
    attr::Hash

    REnvironment() = new(nothing, nothing, nothing, Hash())
end

immutable RRaw <: ROBJ{RAWSXP}
    data::Vector{UInt8}
    attr::Hash
end

immutable RS4Obj <: ROBJ{S4SXP}
    attr::Hash
end

type RExtPtr <: ROBJ{EXTPTRSXP}
    protected
    tag
    attr::Hash

    RExtPtr() = new(nothing, nothing, Hash())
end

type RBytecode <: ROBJ{BCODESXP}
    attr::Hash
    tag
    car
    cdr
    RBytecode(code = nothing, consts = nothing, attr::Hash = Hash()) =
        new(attr, nothing, code, consts)
end

immutable RPackage <: RSEXPREC{PACKAGESXP}
    name::Vector{RString}
end

immutable RNamespace <: RSEXPREC{NAMESPACESXP}
    name::Vector{RString}
end

# R objects without body (empty environments, missing args etc)
immutable RDummy{S} <: RSEXPREC{S}
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
getattr(ro::ROBJ, attrnm) = getindex(ro.attr, attrnm).data
getattr(ro::ROBJ, attrnm, default) = hasattr(ro, attrnm) ? getindex(ro.attr, attrnm).data : default

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
