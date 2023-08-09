const SXType = UInt8 # stores the type of SEXPREC

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
const ANYSXP =      0x12 # make "any" args work. Used in specifying types for symbol registration to mean anything is okay
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
 = Administrative SXP values (from serialize.c)
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
const ALTREP_SXP =        0xEE

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
abstract type RSEXPREC{S} end

sxtype(sxt::Type{T}) where T <: RSEXPREC{S} where S = S
sxtype(sxt::RSEXPREC) = sxtype(typeof(sxt))

"""
R symbol.
Not quite the same as a Julia symbol.
"""
struct RSymbol <: RSEXPREC{SYMSXP}
    displayname::RString
end

Base.string(symbol::RSymbol) = symbol.displayname

"""
Base class for all R types (objects) that can have attributes.
"""
abstract type ROBJ{S} <: RSEXPREC{S} end

"""
Base class for all R vector-like objects.
"""
abstract type RVEC{T, S} <: ROBJ{S} end

rvec_eltype(::Type{<:RVEC{T}}) where T = T
rvec_eltype(v::RVEC) = rvec_eltype(typeof(v))

Base.length(rl::RVEC) = length(rl.data)
Base.size(rv::RVEC) = size(rv.data) # overriden for RList to handle data.frame
Base.isempty(rv::RVEC) = isempty(rv.data)

"""
R vector object.
"""
struct RVector{T, S} <: RVEC{T, S}
    data::Vector{T}
    attr::Hash                   # collection of R object attributes

    RVector{T,S}(v::Vector{T}=T[], attr::Hash=Hash()) where {T,S} =
        new{T,S}(v, attr)
end

# add unique attribute storage to ROBJ if one doesn't have it
addattr(v::RVector{T, S}) where {T,S} =
    v.attr === emptyhash ? RVector{T, S}(v.data, Hash()) : v

const RLogicalVector = RVector{Int32, LGLSXP}
const RIntegerVector = RVector{Int32, INTSXP}
const RNumericVector = RVector{Float64, REALSXP}
const RComplexVector = RVector{ComplexF64, CPLXSXP}

"""
R vector object with explicit NA values.
"""
struct RNullableVector{T, S} <: RVEC{T, S}
    data::Vector{T}
    na::BitVector                # mask of NA elements
    attr::Hash                   # collection of R object attributes
end

const RStringVector = RNullableVector{RString,STRSXP}
const RList = RVector{RSEXPREC,VECSXP}  # "list" in R == Julia cell array
const RExprList = RVector{RSEXPREC,EXPRSXP} # expression "list"

Base.size(rl::RList) = isdataframe(rl) ? (length(rl.data[1]), length(rl.data)) : size(rl.data)

# R objects without body (empty environments, missing args etc)
struct RDummy{S} <: RSEXPREC{S}
end

const RNull = RDummy{NILSXP}
const RGlobalEnv = RDummy{GLOBALENV_SXP}
const RBaseEnv = RDummy{BASEENV_SXP}
const REmptyEnv = RDummy{EMPTYENV_SXP}

mutable struct REnvironment <: ROBJ{ENVSXP}
    enclosed::RSEXPREC
    frame::RSEXPREC
    hashtab::RSEXPREC
    attr::Hash

    REnvironment() = new(RNull(), RNull(), RNull(), Hash())
end

mutable struct RNamespace <: RSEXPREC{NAMESPACESXP}
    name::Vector{RString}
end

mutable struct RPackage <: RSEXPREC{PACKAGESXP}
    name::Vector{RString}
end

# any types that could be used as R environment in promises and closures
const REnvTypes = Union{REnvironment, RNamespace, RDummy}

"""
Representation of R's paired list-like structures (`LISTSXP`, `LANGSXP`).
Unlike R which represents these as singly-linked list,
`RPairList` uses vector representation.
"""
struct RPairList <: ROBJ{LISTSXP}
    items::Vector{RSEXPREC}
    tags::Vector{RString}
    attr::Hash

    RPairList(attr::Hash = Hash()) = new(RSEXPREC[], RString[], attr)
end

Base.length(list::RPairList) = length(list.items)
Base.size(list::RPairList) = size(list.items)
Base.isempty(list::RPairList) = isempty(list.items)

function Base.push!(pl::RPairList, item::RSEXPREC, tag::RString)
    push!(pl.tags, tag)
    push!(pl.items, item)
end

struct RClosure <: ROBJ{CLOSXP}
    formals::RSEXPREC
    body::RSEXPREC
    env::REnvTypes
    attr::Hash
end

struct RPromise <: ROBJ{PROMSXP}
    value::RSEXPREC
    expr::RSEXPREC
    env::REnvTypes
    attr::Hash
end

struct RBuiltin <: RSEXPREC{BUILTINSXP}
    internal_function::RString
end

struct RRaw <: ROBJ{RAWSXP}
    data::Vector{UInt8}
    attr::Hash
end

struct RS4Obj <: ROBJ{S4SXP}
    attr::Hash
end

mutable struct RExtPtr <: ROBJ{EXTPTRSXP}
    protected
    tag
    attr::Hash

    RExtPtr() = new(nothing, nothing, Hash())
end

mutable struct RBytecode <: ROBJ{BCODESXP}
    attr::Hash
    tag
    car
    cdr
    RBytecode(code = nothing, consts = nothing, attr::Hash = Hash()) =
        new(attr, nothing, code, consts)
end

struct RAltRep <: ROBJ{ALTREP_SXP}
    info
    state
    attr::Hash
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

getdata(ro::RSEXPREC) =
    throw(UnsupportedROBJ(sxtype(ro), "Don't know how to get data from $(typeof(ro))"))
getdata(ro::Union{RVector, RNullableVector, RRaw}) = ro.data

getattr(ro::ROBJ, attrnm) = getdata(getindex(ro.attr, attrnm))
getattr(ro::ROBJ, attrnm, default) = hasattr(ro, attrnm) ? getdata(getindex(ro.attr, attrnm)) : default

Base.names(ro::ROBJ) = getattr(ro, "names")

# class of an R object
class(x::RSEXPREC) = emptystrvec # not an object
class(ro::ROBJ) = getattr(ro, "class", emptystrvec)::Vector{RString}

# check if R object inherits from a given class
inherits(x::RSEXPREC, classname) = false
inherits(ro::ROBJ, classname::AbstractString) = any(isequal(classname), class(ro))
# check if R object inherits from all given classes
inherits(ro::ROBJ, classnames::AbstractVector{<:AbstractString}) =
    all(classname -> any(isequal(classname), class(ro)), classnames)

isdataframe(rl::RList) = inherits(rl, "data.frame")
isfactor(ri::RIntegerVector) = inherits(ri, "factor")

row_names(ro::ROBJ) = getattr(ro, "row.names", emptystrvec)

altrep_typename(ar::RAltRep) =
    isa(ar.info, RPairList) && length(ar.info) >= 1 && isa(ar.info.items[1], RSymbol) ?
    string(ar.info.items[1]) : nothing

function unsupported_altrep_message(ar::RAltRep)
    artype = altrep_typename(ar)
    if artype !== nothing
        return "Unsupported AltRep SEXP variant ($artype)"
    else
        return "Unsupported AltRep SEXP variant (info type $(typeof(ar.info)))"
    end
end

function iswrapped(ar::RAltRep)
    artype = altrep_typename(ar)
    return artype !== nothing && startswith(artype, "wrap_")
end

function iscompactseq(ar::RAltRep)
    artype = altrep_typename(ar)
    return artype !== nothing && occursin(r"^compact_.+seq$", artype)
end

# unwrap data contained in RAltRep
function unwrap(ar::RAltRep)
    # the first element of the AltRep state should be the wrapped one
    if !isa(ar.state, RPairList) || length(ar.state) == 0
        error("Unexpected state of \"$(arinfo)\" AltRep SEXP")
    end

    data = ar.state.items[1] # the actual data
    # recover object attributes from the AltRep head
    for (attrname, attr) in ar.attr
        if !haskey(data.attr, attrname)
            if data.attr === emptyhash
                # make sure data has its own dedicated attribute storage
                data = addattr(data)
            end
            data.attr[attrname] = attr
        end
    end
    return data
end

# convert R compact sequence to Julia range
function jlrange(ar::RAltRep)
    artype = altrep_typename(ar)
    if string(artype) == "compact_intseq"
        T = Int
    elseif string(artype) == "compact_realseq"
        T = Float64
    else
        error("Unsupported AltRep SEXP variant ($artype)")
    end
    if !(ar.state isa RVEC && rvec_eltype(ar.state) <: Number && length(ar.state) == 3)
        error("$artype: expected 3-element number vector")
    end
    seqdef = getdata(ar.state)
    return range(T(seqdef[2]), length=Int(seqdef[1]), step=seqdef[3] != 1 ? T(seqdef[3]) : nothing)
end

# accessing AltRep data is special
function getdata(ar::RAltRep)
    if iswrapped(ar)
        return getdata(unwrap(ar))
    elseif iscompactseq(ar)
        return jlrange(ar)
    else
        @warn unsupported_altrep_message(ar)
        return nothing
    end
end

