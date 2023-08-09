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
function readpairedobjects(ctx::RDAContext, fl::RDATag)
    res = RPairList(readattrs(ctx, fl))
    ifl = fl # RDATag for the list item
    while true
        if sxtype(ifl) == sxtype(fl)
            if hastag(ifl)
                tag = readitem(ctx)
                if isa(tag, RSymbol)
                    nm = tag.displayname
                else
                    nm = emptyhashkey
                end
            else
                nm = emptyhashkey
            end
            item = readitem(ctx)
            push!(res, item, nm)
            ifl = readuint32(ctx.io)
            # read the item attributes
            # FIXME what to do with the attributes?
            (sxtype(ifl) == sxtype(fl)) && readattrs(ctx, ifl)
        elseif sxtype(ifl) == NILVALUE_SXP # end of list
            break
        else # end of list (not a single-linked list item)
            # it's not clear whether it's an error of handling AltReps
            # or a feature of AltReps (it only occurs within AltReps)
            # normally pairlists should be terminated by NILVALUE_SXP
            @warn "$(sxtypelabel(item)) element in a $(sxtypelabel(res)) list, assuming it's the last element"
            item = readitem(ctx, ifl)
            push!(res, item, emptyhashkey)
            break
        end
    end

    return res
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
    attrs = readattrs(ctx, fl)
    env = hastag(fl) ? readitem(ctx) : RNull()
    formals = readitem(ctx)
    body = readitem(ctx)
    return RClosure(formals, body, env, attrs)
end

function readpromise(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == PROMSXP
    res = RPromise(readattrs(ctx, fl))
    hastag(fl) && (res.env = readitem(ctx))
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
