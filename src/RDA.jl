# Read saved R datasets in the RDA2 or RDX2 format
# Files written in this format often have the extension .rda or .RData

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
## Constants used as NA patterns in R.
## (I assume 1954 is the year of Ross's birth or something like that.)
##
##############################################################################

if ENDIAN_BOM == 0x01020304
    const R_NA_FLOAT64 = reinterpret(Float64, [0x7ff00000, @compat(UInt32(1954))])[1]
else
    const R_NA_FLOAT64 = reinterpret(Float64, [@compat(UInt32(1954)), 0x7ff00000])[1]
end
const R_NA_INT32 = typemin(Int32)
const R_NA_STRING = "NA"

##############################################################################
##
## Julia types encapsulating various types of R SEXPRECs
##
##############################################################################

typealias Hash Dict{String, Any}
const nullhash = Hash()

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
## R objects in the file are preceded by a UInt32 giving the type and
## some flags.  These functions unpack bits in the flags.  The isobj
## bit might be useful for distinguishing an RInteger from a factor or
## an RList from a data.frame.
##
##############################################################################

typealias RDATag UInt32

isobj(fl::RDATag) = (fl & 0x00000100) != 0
hasattr(fl::RDATag) = (fl & 0x00000200) != 0
hastag(fl::RDATag) = (fl & 0x00000400) != 0

if VERSION < v"0.4-"
    sxtype = uint8
else
    sxtype(fl::RDATag) = fl % UInt8
end

##############################################################################
##
## Utilities for reading a single data element.
## The read<type>orNA functions are needed because the ASCII format
## stores the NA as the string 'NA'.  Perhaps it would be easier to
## wrap the conversion in a try/catch block.
##
##############################################################################

LONG_VECTOR_SUPPORT = (WORD_SIZE > 32) # disable long vectors support on 32-bit machines

if LONG_VECTOR_SUPPORT
    typealias RVecLength Int64
else
    typealias RVecLength Int
end

# abstract RDA format IO stream wrapper
abstract RDAIO

type RDAXDRIO{T<:IO} <: RDAIO # RDA XDR(binary) format IO stream wrapper
    sub::T             # underlying IO stream
    buf::Vector{UInt8} # buffer for strings

    RDAXDRIO( io::T ) = new( io, Array(UInt8, 1024) )
end
RDAXDRIO{T <: IO}(io::T) = RDAXDRIO{T}(io)

readint32(io::RDAXDRIO) = ntoh(read(io.sub, Int32))
readuint32(io::RDAXDRIO) = ntoh(read(io.sub, UInt32))
readfloat64(io::RDAXDRIO) = ntoh(read(io.sub, Float64))

readintorNA(io::RDAXDRIO) = readint32(io)
readintorNA(io::RDAXDRIO, n::RVecLength) = map!(ntoh, read(io.sub, Int32, n))

readfloatorNA(io::RDAXDRIO) = readfloat64(io)
readfloatorNA(io::RDAXDRIO, n::RVecLength) = map!(ntoh, read(io.sub, Float64, n))

readuint8(io::RDAXDRIO, n::RVecLength) = readbytes(io.sub, n)

function readnchars(io::RDAXDRIO, n::Int32)  # a single character string
    readbytes!(io.sub, io.buf, n)
    bytestring(pointer(io.buf), n)::String
end

type RDAASCIIIO{T<:IO} <: RDAIO # RDA ASCII format IO stream wrapper
    sub::T              # underlying IO stream

    RDAASCIIIO( io::T ) = new( io )
end
RDAASCIIIO{T <: IO}(io::T) = RDAASCIIIO{T}(io)

readint32(io::RDAASCIIIO) = parse(Int32, readline(io.sub))
readuint32(io::RDAASCIIIO) = parse(UInt32, readline(io.sub))
readfloat64(io::RDAASCIIIO) = parse(Float64, readline(io.sub))

function readintorNA(io::RDAASCIIIO)
    str = chomp(readline(io.sub));
    str == R_NA_STRING ? R_NA_INT32 : parse(Int32, str)
end
readintorNA(io::RDAASCIIIO, n::RVecLength) = Int32[readintorNA(io) for i in 1:n]

function readfloatorNA(io::RDAASCIIIO)
    str = chomp(readline(io.sub));
    str == R_NA_STRING ? R_NA_FLOAT64 : parse(Float64, str)
end
readfloatorNA(io::RDAASCIIIO, n::RVecLength) = Float64[readfloatorNA(io) for i in 1:n]

readuint8(io::RDAASCIIIO, n::RVecLength) = UInt8[hex2bytes(chomp(readline(io.sub)))[1] for i in 1:n] # FIXME optimize for speed

function readnchars(io::RDAASCIIIO, n::Int32)  # reads N bytes-sized string
    if (n==-1) return "" end
    str = unescape_string(chomp(readline(io.sub)))
    length(str) == n || error("Character string length mismatch")
    str
end

type RDANativeIO{T<:IO} <: RDAIO # RDA native binary format IO stream wrapper (TODO)
    sub::T               # underlying IO stream

    RDANativeIO( io::T ) = new( io )
end
RDANativeIO{T <: IO}(io::T) = RDANativeIO{T}(io)

function rdaio(io::IO, formatcode::AbstractString)
    if formatcode == "X" RDAXDRIO(io)
    elseif formatcode == "A" RDAASCIIIO(io)
    elseif formatcode == "B" RDANativeIO(io)
    else error( "Unrecognized RDA format \"$formatcode\"" )
    end
end

if LONG_VECTOR_SUPPORT
    # reads the length of any data vector from a stream
    # from R's serialize.c
    function readlength(io::RDAIO)
        len = convert(RVecLength, readint32(io))
        if (len < -1) error("negative serialized length for vector")
        elseif (len >= 0)
            return len
        else # big vectors, the next 2 ints encode the length
            len1, len2 = convert(RVecLength, readint32(io)), convert(RVecLength, readint32(io))
            # sanity check for now
            if (len1 > 65536) error("invalid upper part of serialized vector length") end
            return (len1 << 32) + len2
        end
    end
else
    # reads the length of any data vector from a stream
    # fails when long (> 2^31-1) vector encountered
    # from R's serialize.c
    function readlength(io::RDAIO)
        len = convert(RVecLength, readint32(io))
        if (len >= 0)
            return len
        elseif (len < -1)
            error("negative serialized length for vector")
        else
            error("negative serialized vector length:\nperhaps long vector from 64-bit version of R?")
        end
    end
end

immutable CHARSXProps # RDA CHARSXP properties
  levs::UInt32       # level flags (encoding etc) TODO process
  nchar::Int32       # string length, -1 for NA strings
end

function readcharsxprops(io::RDAIO) # read character string encoding and length
    fl = readuint32(io)
    @assert sxtype(fl) == CHARSXP
    @assert !hasattr(fl)
### watch out for levs in here.  Generally it has the value 0x40 so that fl = 0x00040009 (262153)
### if levs == 0x00 then the next line should be -1 to indicate the NA_STRING
    CHARSXProps(fl >> 12, readint32(io))
end

function readcharacter(io::RDAIO)  # a single character string
    props = readcharsxprops(io)
    props.nchar==-1 ? "" : readnchars(io, props.nchar)
end

function readcharacter(io::RDAIO, n::RVecLength)  # a single character string
    res = fill("", n)
    na = falses(n)
    for i in 1:n
        props = readcharsxprops(io)
        if (props.nchar==-1) na[i] = true
        else res[i] = readnchars(io, props.nchar)
        end
    end
    return res, na
end

##############################################################################
##
## Utilities for reading compound RDA items: lists, arrays etc
##
##############################################################################

type RDAContext{T <: RDAIO}    # RDA reading context
    io::T                      # R input stream

    # RDA properties
    fmtver::UInt32             # RDA format version
    Rver::VersionNumber        # R version that has written RDA
    Rmin::VersionNumber        # R minimal version to read RDA

    # behaviour
    convertdataframes::Bool    # if R dataframe objects should be automatically converted into DataFrames

    # intermediate data
    ref_tab::Vector{RSEXPREC}  # SEXP array for references

    function RDAContext(io::T, kwoptions::Vector{Any})
        fmtver = readint32(io)
        rver = readint32(io)
        rminver = readint32(io)
        kwdict = Dict{Symbol,Any}(kwoptions)
        new(io,
            fmtver,
            VersionNumber( div(rver,65536), div(rver%65536, 256), rver%256 ),
            VersionNumber( div(rminver,65536), div(rminver%65536, 256), rminver%256 ),
            get(kwdict,:convertdataframes,false),
            RSEXPREC[])
    end
end

RDAContext{T <: RDAIO}(io::T, kwoptions::Vector{Any}) = RDAContext{T}(io, kwoptions)

function registerref(ctx::RDAContext, obj::RSEXPREC)
    push!(ctx.ref_tab, obj)
    obj
end

# converters from selected RSEXPREC to Hash
# They are used to translate SEXPREC attributes into Hash

function Base.convert(::Type{Hash}, pl::RPairList)
    res = Hash()
    for i in 1:length(pl.items)
        setindex!(res, pl.items[i], pl.tags[i])
    end
    res
end

function Base.convert(::Type{Hash}, ptr::RExtPtr)
    Hash(Pair(ptr.tag.displayname, ptr.protected))
end

function readnamedobjects(ctx::RDAContext, fl::RDATag)
    if !hasattr(fl) return Hash() end
    convert(Hash, readitem(ctx))
end

readattrs(ctx::RDAContext, fl::RDATag) = readnamedobjects(ctx, fl)

function readdummy(ctx::RDAContext, fl::RDATag)
    # for reading elements without body,
    # e.g. NULL, empty environment etc
    null
end

readnil = readdummy

function readnumeric(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == REALSXP
    RNumeric(readfloatorNA(ctx.io, readlength(ctx.io)),
             readattrs(ctx, fl))
end

function readinteger(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == INTSXP
    RInteger(readintorNA(ctx.io, readlength(ctx.io)),
             readattrs(ctx, fl))
end

function readlogical(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == LGLSXP # excluding this check, the method is the same as readinteger()
    RLogical(readintorNA(ctx.io, readlength(ctx.io)),
             readattrs(ctx, fl))
end

function readcomplex(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == CPLXSXP
    n = readlength(ctx.io)
    data = readfloatorNA(ctx.io, 2n)
    RComplex(Complex128[@compat(Complex128(data[i],data[i+1])) for i in 2(1:n)-1],
             readattrs(ctx, fl))
end

function readstring(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == STRSXP
    RString(readcharacter(ctx.io, readlength(ctx.io))...,
            readattrs(ctx, fl))
end

function readlist(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == VECSXP
    n = readlength(ctx.io)
    res = RList([readitem(ctx) for i in 1:n],
                readattrs(ctx, fl))
    if ctx.convertdataframes && isdataframe(res)
        DataFrame(res)
    else
        res
    end
end

function readrefindex(ctx::RDAContext, fl::RDATag)
    ix = fl >> 8
    ix != 0 ? ix : readint32(ctx.io)
end

function readref(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == REFSXP
    ix = readrefindex(ctx, fl)
    if ( ix > length( ctx.ref_tab ) )
        throw( BoundsError( "undefined reference index=$ix" ) )
    else
        return ctx.ref_tab[ix]
    end
end

function readsymbol(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == SYMSXP
    registerref( ctx, RSymbol(readcharacter(ctx.io)) )
end

function readS4(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == S4SXP
    # S4 objects doesn't contain any data other than its attributes
    # FIXME S4 is read just as a named hash of its attributes
    RS4Obj( readattrs(ctx, fl) )
end

function readenv(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == ENVSXP
    is_locked = readint32( ctx.io )
    res = registerref( ctx, REnvironment() ) # registering before reading the contents
    res.enclosed = readitem(ctx)
    res.frame = readitem(ctx)
    res.hashtab = readitem(ctx)
    attr = readitem(ctx)
    if isa(attr, Hash)
        res.attr = attr
    end
    return res
end

function readname(ctx)
    if readint32(ctx.io) != 0 error( "Names in persistent strings not supported") end
    n = readint32(ctx.io)
    return String[ readcharacter(ctx.io) for i in 1:n ]
end

function readnamespace(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == NAMESPACESXP
    registerref( ctx, RNamespace(readname(ctx)) )
end

function readpackage(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == PACKAGESXP
    registerref( ctx, RPackage(readname(ctx)) )
end

# reads single-linked lists R objects
function readpairedobjects(ctx::RDAContext, fl::RDATag)
    res = RPairList( readattrs(ctx, fl) )
    while sxtype(fl) != NILVALUE_SXP
        if ( hastag(fl) )
            tag = readitem(ctx)
            if ( isa(tag, RSymbol) )
                nm = tag.displayname
            else
                nm = "\0"
            end
        else
            nm = "\0"
        end
        push!( res, readitem(ctx), nm )
        fl = readuint32(ctx.io)
        readattrs(ctx, fl)
    end

    res
end

function readpairlist(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == LISTSXP
    readpairedobjects(ctx, fl)
end

function readlang(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == LANGSXP
    readpairedobjects(ctx, fl)
end

function readclosure(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == CLOSXP
    res = RClosure( readattrs(ctx, fl) )
    if ( hastag(fl) )
        res.env = readitem(ctx)
    end
    res.formals = readitem(ctx)
    res.body = readitem(ctx)
    return res
end

function readpromise(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == PROMSXP
    res = RPromise( readattrs(ctx, fl) )
    if ( hastag(fl) )
        res.env = readitem(ctx)
    end
    res.value = readitem(ctx)
    res.expr = readitem(ctx)
    return res
end

function readraw(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == RAWSXP
    n = readlength(ctx.io)
    RRaw(readuint8(ctx.io, n), readattrs(ctx, fl))
end

# reads built-in R objects
function readbuiltin(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == BUILTINSXP
    res = readnchars(ctx.io, readint32(ctx.io))
    readattrs(ctx, fl)
    res
end

function readextptr(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == EXTPTRSXP
    res = registerref( ctx, RExtPtr() ) # registering before reading the contents
    res.protected = readitem(ctx)
    res.tag = readitem(ctx)
    res.attr = readattrs(ctx, fl)
end

type BytecodeContext # bytecode reading context
    ctx::RDAContext  # parent RDA context
    ref_tab::Vector  # table of bytecode references

    BytecodeContext( ctx::RDAContext, nrefs::Int32 ) = new( ctx, Array( Any, int(nrefs) ) )
end

function readbytecodelang(bctx::BytecodeContext, bctype::Int32)
    if bctype == BCREPREF # refer to an already defined bytecode
        return bctx.ref_tab[readint32(bctx.ctx.io)+1]
    elseif bctype ∈ [ BCREPDEF, LANGSXP, LISTSXP, ATTRLANGSXP, ATTRLISTSXP ]
        pos = 0
        hasattr = false
        if bctype == BCREPDEF # define a reference
            pos = readint32(bctx.ctx.io)+1
            bctype = readint32(bctx.ctx.io)
        end # now bctype might be updated
        if bctype == ATTRLANGSXP
            bctype = LANGSXP # it's an R expression
            hasattr = true
        elseif bctype == ATTRLISTSXP
            bctype = LISTSXP # it's pairlist
            hasattr = true
        end
        res = RBytecode() # FIXME create a RPairlist if LANG/LISTSXP?
        if ( hasattr ) res.attr = readitem(bctx.ctx) end
        res.tag = readitem(bctx.ctx)
        res.car = readbytecodelang(bctx, readint32(bctx.ctx.io))
        res.cdr = readbytecodelang(bctx, readint32(bctx.ctx.io))
        if ( pos > 0 ) setindex!(bctx.ref_tab, res, pos) end
        return res
    else
        return readitem(bctx.ctx)
    end
end

function readbytecodeconsts( bctx::BytecodeContext )
    nconsts = readint32(bctx.ctx.io)
    RList( [ begin
        bctype = readint32(bctx.ctx.io)
        if bctype == BCODESXP
            readbytecodecontents(bctx)
        elseif bctype ∈ [ BCREPDEF, BCREPDEF, LANGSXP, LISTSXP, ATTRLANGSXP, ATTRLISTSXP ]
            readbytecodelang(bctx, bctype)
        else
            readitem(bctx.ctx)
        end
        end
        for i in 1:nconsts ] )
end

function readbytecodecontents( bctx::BytecodeContext )
    RBytecode( readitem(bctx.ctx),
               readbytecodeconsts(bctx) )
end

function readbytecode( ctx::RDAContext, fl::RDATag )
    @assert fl == BCODESXP
    res = readbytecodecontents( BytecodeContext( ctx, readint32( ctx.io ) ) )
    res.attrs = readattrs( ctx, fl )
end

function readunsupported( ctx::RDAContext, fl::RDATag )
    error( "Reading SEXPREC of type $(sxtype(fl)) ($(SXTypes[sxtype(fl)].name)) is not supported" )
end

immutable SXTypeInfo
    name::String         # type name
    reader::Function     # function to read the contents from RDA stream
end

const SXTypes = @compat Dict{SXType, SXTypeInfo}(      # Map SEXPREC type ids to names
    NILSXP     => SXTypeInfo("NULL",readdummy),
    SYMSXP     => SXTypeInfo("Symbol",readsymbol),
    LISTSXP    => SXTypeInfo("Pairlist",readpairlist),
    CLOSXP     => SXTypeInfo("Closure",readclosure),
    ENVSXP     => SXTypeInfo("Environment",readenv),
    PROMSXP    => SXTypeInfo("Promise",readpromise),
    LANGSXP    => SXTypeInfo("Lang",readlang),
    SPECIALSXP => SXTypeInfo("Special",readbuiltin),
    BUILTINSXP => SXTypeInfo("Builtin",readbuiltin),
    CHARSXP    => SXTypeInfo("Char",readunsupported),
    LGLSXP     => SXTypeInfo("Logical",readlogical),
    INTSXP     => SXTypeInfo("Integer",readinteger),
    REALSXP    => SXTypeInfo("Real",readnumeric),
    CPLXSXP    => SXTypeInfo("Complex",readcomplex),
    STRSXP     => SXTypeInfo("String",readstring),
    DOTSXP     => SXTypeInfo("Dot",readunsupported),
    ANYSXP     => SXTypeInfo("Any",readunsupported),
    VECSXP     => SXTypeInfo("List",readlist),
    EXPRSXP    => SXTypeInfo("Expr",readunsupported),
    BCODESXP   => SXTypeInfo("ByteCode",readbytecode),
    EXTPTRSXP  => SXTypeInfo("XPtr",readextptr),
    WEAKREFSXP => SXTypeInfo("WeakRef",readunsupported),
    RAWSXP     => SXTypeInfo("Raw",readraw),
    S4SXP      => SXTypeInfo("S4",readS4),
    NEWSXP     => SXTypeInfo("New",readunsupported),
    FREESXP    => SXTypeInfo("Free",readunsupported),
    FUNSXP     => SXTypeInfo("Function",readunsupported),
    BASEENV_SXP       => SXTypeInfo("BaseEnv",readdummy),
    EMPTYENV_SXP      => SXTypeInfo("EmptyEnv",readdummy),
    BCREPREF          => SXTypeInfo("BCREPREF",readunsupported), # handled within readbytecode()
    BCREPDEF          => SXTypeInfo("BCREPDEF",readunsupported), # handled within readbytecode()
    GENERICREFSXP     => SXTypeInfo("GenericRef",readunsupported),
    CLASSREFSXP       => SXTypeInfo("ClassRef",readunsupported),
    PERSISTSXP        => SXTypeInfo("Persist",readunsupported),
    PACKAGESXP        => SXTypeInfo("Package",readpackage),
    NAMESPACESXP      => SXTypeInfo("Namespace",readnamespace),
    BASENAMESPACE_SXP => SXTypeInfo("BaseNamespace",readdummy),
    MISSINGARG_SXP    => SXTypeInfo("MissingArg",readdummy),
    UNBOUNDVALUE_SXP  => SXTypeInfo("UnboundValue",readdummy),
    GLOBALENV_SXP     => SXTypeInfo("GlobalEnv",readdummy),
    NILVALUE_SXP      => SXTypeInfo("NilValue",readnil),
    REFSXP            => SXTypeInfo("Ref",readref)
)

function readitem(ctx::RDAContext)
    fl = readuint32(ctx.io)
    sxt = sxtype(fl)
    if !haskey(SXTypes, sxt) error("$name: encountered unknown SEXPREC type $sxt") end
    sxtinfo = SXTypes[sxt]
    return sxtinfo.reader(ctx, fl)
### Should not occur at the top level
###    if sxt == NILVALUE_SXP return nothing end      # terminates dotted pair lists
###    if sxt == CHARSXP return readcharacter(ctx.io, ff) end
end

function read_rda(io::IO, kwoptions::Vector{Any})
    header = chomp(readline(io))
    @assert header[1] == 'R' # readable header (or RDX2)
    @assert header[2] == 'D'
    @assert header[4] == '2'
    ctx = RDAContext(rdaio(io, chomp(readline(io))), kwoptions)
    @assert ctx.fmtver == 2    # format version
#    println("Written by R version $(ctx.Rver)")
#    println("Minimal R version: $(ctx.Rmin)")
    return readnamedobjects(ctx, 0x00000200)
end

read_rda(io::IO; kwoptions...) = read_rda(io, kwoptions)

read_rda(fnm::String; kwoptions...) = gzopen(fnm) do io read_rda(io, kwoptions) end

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

##############################################################################
##
## Conversion of intermediate R objects into DataArray and DataFrame objects
##
##############################################################################

namask(rl::RLogical) = bitpack(rl.data .== R_NA_INT32)
namask(ri::RInteger) = bitpack(ri.data .== R_NA_INT32)
namask(rn::RNumeric) = bitpack([rn.data[i] === R_NA_FLOAT64 for i in 1:length(rn.data)])
namask(rc::RComplex) = bitpack([rc.data[i].re === R_NA_FLOAT64 ||
                                rc.data[i].im === R_NA_FLOAT64 for i in 1:length(rc.data)])
namask(rv::RNullableVector) = rv.na

DataArrays.data(rv::RVEC) = DataArray(rv.data, namask(rv))

function DataArrays.data(ri::RInteger)
    if !isfactor(ri) return DataArray(ri.data, namask(ri)) end
    # convert factor into PooledDataArray
    pool = getattr(ri, "levels", emptystrvec)
    sz = length(pool)
    REFTYPE = sz <= typemax(UInt8)  ? UInt8 :
              sz <= typemax(UInt16) ? UInt16 :
              sz <= typemax(UInt32) ? UInt32 :
                                      UInt64
    dd = ri.data
    dd[namask(ri)] = 0
    refs = convert(Vector{REFTYPE}, dd)
    return PooledDataArray(DataArrays.RefArray(refs), pool)
end

function Base.convert(::Type{DataFrame}, rl::RList)
    DataFrame(map(data, rl.data),
              Symbol[identifier(x) for x in names(rl)])
end
