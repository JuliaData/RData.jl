##############################################################################
##
## Utilities for reading compound RDA items: lists, arrays etc
##
##############################################################################

function readdummy(ctx::RDAContext, fl::RDATag)
    # for reading elements without body,
    # e.g. NULL, empty environment etc
    RDummy{sxtype(fl)}()
end

function readattrs(ctx::RDAContext, fl::RDATag)
    if !hasattr(fl) return emptyhash
    else convert(Hash, readitem(ctx)) end
end

readnil = readdummy

function readnumeric(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == REALSXP
    RNumericVector(readfloatorNA(ctx.io, readlength(ctx.io)),
                   readattrs(ctx, fl))
end

function readinteger(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == INTSXP
    RIntegerVector(readintorNA(ctx.io, readlength(ctx.io)),
                   readattrs(ctx, fl))
end

function readlogical(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == LGLSXP # excluding this check, the method is the same as readinteger()
    RLogicalVector(readintorNA(ctx.io, readlength(ctx.io)),
                   readattrs(ctx, fl))
end

function readcomplex(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == CPLXSXP
    n = readlength(ctx.io)
    v = Vector{ComplexF64}(undef, n)
    readfloatorNA!(ctx.io, reinterpret(Float64, v))
    RComplexVector(v, readattrs(ctx, fl))
end

function readstring(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == STRSXP
    RStringVector(readcharacter(ctx.io, readlength(ctx.io))...,
                  readattrs(ctx, fl))
end

function readlist(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == VECSXP || sxtype(fl) == EXPRSXP
    n = readlength(ctx.io)
    RVector{RSEXPREC, sxtype(fl)}(
        RSEXPREC[readitem(ctx) for _ in 1:n],
        readattrs(ctx, fl))
end

function readref(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == REFSXP
    ix = fl >> 8
    ix = ix != 0 ? ix : readint32(ctx.io)
    (ix <= length(ctx.ref_tab)) || throw(BoundsError("undefined reference index=$ix"))
    return ctx.ref_tab[ix]
end

function readsymbol(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == SYMSXP
    registerref!(ctx, RSymbol(readcharacter(ctx.io)))
end

function readS4(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == S4SXP
    # S4 objects doesn't contain any data other than its attributes
    # FIXME S4 is read just as a named hash of its attributes
    RS4Obj(readattrs(ctx, fl))
end

function readenv(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == ENVSXP
    is_locked = readint32(ctx.io)
    res = registerref!(ctx, REnvironment()) # registering before reading the contents
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
    (readint32(ctx.io) == zero(Int32)) ||
        error("Names in persistent strings not supported")
    n = readint32(ctx.io)
    return RString[readcharacter(ctx.io) for i in 1:n]
end

function readnamespace(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == NAMESPACESXP
    registerref!(ctx, RNamespace(readname(ctx)))
end

function readpackage(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == PACKAGESXP
    registerref!(ctx, RPackage(readname(ctx)))
end

# reads single-linked lists R objects
# the type of the result is RSpecialList{S},
# where S is the SXTYPE of the R object
function readsinglelinkedlist(::Val{S}, ctx::RDAContext, fl::RDATag) where S
    res = RSpecialList{S}(readattrs(ctx, fl))
    tag = hastag(fl) ? readitem(ctx) : RNull()
    carfl = fl # RDATag for the CAR of the current list link
    while carfl != NILVALUE_SXP
        if !isempty(res) # head tag was read already
            carfl = readuint32(ctx.io) # CAR container type
            (carfl == NILVALUE_SXP) && break
            # read the item attributes
            # FIXME what to do with the attributes?
            attrs = readattrs(ctx, carfl)
            tag = hastag(carfl) ? readitem(ctx) : RNull()
        end
        if isa(tag, RSymbol)
            nm = tag.displayname
        else
            isa(tag, RNull) || @warn "$(sxtypelabel(sxtype(fl))) link has unexpected tag type $(sxtypelabel(tag))"
            nm = emptyhashkey
        end
        iscontainer = sxtype(carfl) == sxtype(fl) || sxtype(carfl) == LISTSXP
        #if !iscontainer
        #    @warn "$(sxtypelabel(sxtype(carfl))) CAR element in a $(sxtypelabel(res)) list"
        #end
        item = iscontainer ?
            readitem(ctx) : # item is inside the list link
            readitem(ctx, carfl) # the link is the item
        #if length(res) > 0 && sxtype(last(res.items)) != sxtype(item)
        #    # the items in the list are not required to be of the same type
        #    @warn "$(sxtypelabel(item)) element in a $(sxtypelabel(res)) list, previous was $(sxtypelabel(last(res.items)))"
        #end
        push!(res, item, nm)
        iscontainer || break # no CDR, end of the list
    end

    return res
end

function readsinglelinkedlist(ctx::RDAContext, fl::RDATag)
    S = sxtype(fl)
    # check the SXTYPE is supported
    @assert S == LISTSXP || S == LANGSXP || S == DOTSXP
    readsinglelinkedlist(Val(S), ctx, fl)
end

function readclosure(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == CLOSXP
    attrs = readattrs(ctx, fl)
    env = hastag(fl) ? readitem(ctx) : RNull()
    formals = readitem(ctx)
    body = readitem(ctx)
    return RClosure(formals, body, env, attrs)
end

function readpromise(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == PROMSXP
    attrs = readattrs(ctx, fl)
    env = hastag(fl) ? readitem(ctx) : RNull()
    value = readitem(ctx)
    expr = readitem(ctx)
    return RPromise(value, expr, env, attrs)
end

function readraw(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == RAWSXP
    n = readlength(ctx.io)
    RRaw(readuint8(ctx.io, n), readattrs(ctx, fl))
end

# reads built-in R objects
function readbuiltin(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == BUILTINSXP || sxtype(fl) == SPECIALSXP
    RBuiltin(readnchars(ctx.io, readint32(ctx.io)))
end

function readextptr(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == EXTPTRSXP
    res = registerref!(ctx, RExtPtr()) # registering before reading the contents
    res.protected = readitem(ctx)
    res.tag = readitem(ctx)
    res.attr = readattrs(ctx, fl)
    return res
end

"""
Context for reading R bytecode.
"""
struct BytecodeContext
    ctx::RDAContext                            # parent RDA context
    ref_tab::Vector{Union{RBytecode, Missing}} # table of bytecode references

    BytecodeContext(ctx::RDAContext, nrefs::Int32) =
        new(ctx, Vector{Union{RBytecode, Missing}}(missing, nrefs))
end

const BYTECODELANG_Types = Set([BCREPREF, BCREPDEF, LANGSXP, LISTSXP, ATTRLANGSXP, ATTRLISTSXP])

function readbytecodelang(bctx::BytecodeContext, bctype::Int32)
    if bctype == BCREPREF # refer to an already defined bytecode
        res = bctx.ref_tab[readint32(bctx.ctx.io)+1]
        @assert !ismissing(res)
        return res
    elseif bctype ∈ BYTECODELANG_Types
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
        hasattr && (res.attr = readitem(bctx.ctx))
        res.tag = readitem(bctx.ctx)
        res.car = readbytecodelang(bctx, readint32(bctx.ctx.io))
        res.cdr = readbytecodelang(bctx, readint32(bctx.ctx.io))
        (pos > 0) && setindex!(bctx.ref_tab, res, pos)
        return res
    else
        return readitem(bctx.ctx)
    end
end

function readbytecodeconsts(bctx::BytecodeContext)
    nconsts = readint32(bctx.ctx.io)
    v = fill!(Vector{RSEXPREC}(undef, nconsts), RDummy{NILVALUE_SXP}())
    @inbounds for i = 1:nconsts
        bctype = readint32(bctx.ctx.io)
        v[i] = if bctype == BCODESXP
            readbytecodecontents(bctx)
        elseif bctype ∈ BYTECODELANG_Types
            readbytecodelang(bctx, bctype)
        else
            readitem(bctx.ctx)
        end
    end
    return RList(v)
end

function readbytecodecontents(bctx::BytecodeContext)
    RBytecode(readitem(bctx.ctx),
              readbytecodeconsts(bctx))
end

function readbytecode(ctx::RDAContext, fl::RDATag)
    @assert fl == BCODESXP
    res = readbytecodecontents(BytecodeContext(ctx, readint32(ctx.io)))
    res.attr = readattrs(ctx, fl)
    return res
end

function readaltrep(ctx::RDAContext, fl::RDATag)
    info = readitem(ctx)
    state = readitem(ctx)
    attr = readitem(ctx)
    return RAltRep(info, state, isa(attr, RDummy) ? emptyhash : attr)
end

function readunsupported(ctx::RDAContext, fl::RDATag)
    throw(UnsupportedROBJ(sxtype(fl), "Reading SEXPREC of type $(sxtypelabel(sxtype(fl))) is not supported"))
end

"""
Definition of R type.
"""
struct SXTypeInfo
    name::String         # R type name
    reader::Function     # function to deserialize R type from RDA stream
end

"""
Maps R type id (`SXType`) to its `SXTypeInfo`.
"""
const SXTypes = Dict{SXType, SXTypeInfo}(
    NILSXP     => SXTypeInfo("NULL",readdummy),
    SYMSXP     => SXTypeInfo("Symbol",readsymbol),
    LISTSXP    => SXTypeInfo("Pairlist",readsinglelinkedlist),
    CLOSXP     => SXTypeInfo("Closure",readclosure),
    ENVSXP     => SXTypeInfo("Environment",readenv),
    PROMSXP    => SXTypeInfo("Promise",readpromise),
    LANGSXP    => SXTypeInfo("Lang",readsinglelinkedlist),
    SPECIALSXP => SXTypeInfo("Special",readbuiltin),
    BUILTINSXP => SXTypeInfo("Builtin",readbuiltin),
    CHARSXP    => SXTypeInfo("Char",readunsupported),
    LGLSXP     => SXTypeInfo("Logical",readlogical),
    INTSXP     => SXTypeInfo("Integer",readinteger),
    REALSXP    => SXTypeInfo("Real",readnumeric),
    CPLXSXP    => SXTypeInfo("Complex",readcomplex),
    STRSXP     => SXTypeInfo("String",readstring),
    DOTSXP     => SXTypeInfo("Dot",readsinglelinkedlist),
    ANYSXP     => SXTypeInfo("Any",readunsupported),
    VECSXP     => SXTypeInfo("List",readlist),
    EXPRSXP    => SXTypeInfo("Expr",readlist),
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
    REFSXP            => SXTypeInfo("Ref",readref),
    ALTREP_SXP        => SXTypeInfo("AltRep",readaltrep)
)

sxtypelabel(sxt::SXType) = "$(haskey(SXTypes, sxt) ? SXTypes[sxt].name : "Unknown") (0x$(string(sxt, base=16)))"
sxtypelabel(sxt::RSEXPREC) = sxtypelabel(sxtype(sxt))

function readitem(ctx::RDAContext, fl::RDATag)
    sxt = sxtype(fl)
    haskey(SXTypes, sxt) || throw(UnsupportedROBJ(sxt, "encountered unknown SEXPREC type 0x$(string(fl, base=16))"))
    sxtinfo = SXTypes[sxt]
    return sxtinfo.reader(ctx, fl)
### Should not occur at the top level
###    if sxt == NILVALUE_SXP return nothing end      # terminates dotted pair lists
###    if sxt == CHARSXP return readcharacter(ctx.io, ff) end
end

readitem(ctx::RDAContext) = readitem(ctx, readuint32(ctx.io))
