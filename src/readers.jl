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
    RComplexVector(reinterpret(Complex128, readfloatorNA(ctx.io, 2n)),
                   readattrs(ctx, fl))
end

function readstring(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == STRSXP
    RStringVector(readcharacter(ctx.io, readlength(ctx.io))...,
                  readattrs(ctx, fl))
end

function readlist(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == VECSXP
    n = readlength(ctx.io)
    RList(RSEXPREC[readitem(ctx) for i in 1:n],
                   readattrs(ctx, fl))
end

function readref(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == REFSXP
    ix = fl >> 8
    ix != 0 ? ix : readint32(ctx.io)
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
    return RString[ readcharacter(ctx.io) for i in 1:n ]
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
                nm = emptyhashkey
            end
        else
            nm = emptyhashkey
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
    @assert sxtype(fl) == BUILTINSXP || sxtype(fl) == SPECIALSXP
    RBuiltin( readnchars(ctx.io, readint32(ctx.io)) )
end

function readextptr(ctx::RDAContext, fl::RDATag)
    @assert sxtype(fl) == EXTPTRSXP
    res = registerref( ctx, RExtPtr() ) # registering before reading the contents
    res.protected = readitem(ctx)
    res.tag = readitem(ctx)
    res.attr = readattrs(ctx, fl)
    return res
end

"""
    Context for reading R bytecode.
"""
type BytecodeContext
    ctx::RDAContext  # parent RDA context
    ref_tab::Vector  # table of bytecode references

    BytecodeContext( ctx::RDAContext, nrefs::Int32 ) = new( ctx, Array( Any, Int(nrefs) ) )
end

function readbytecodelang(bctx::BytecodeContext, bctype::Int32)
    if bctype == BCREPREF # refer to an already defined bytecode
        return bctx.ref_tab[readint32(bctx.ctx.io)+1]
    elseif bctype ∈ [ BCREPDEF, LANGSXP, LISTSXP, ATTRLANGSXP, ATTRLISTSXP ] # FIXME define Set constant
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
    v = Vector{RSEXPREC}(nconsts)
    @inbounds for i = 1:nconsts
        bctype = readint32(bctx.ctx.io)
        v[i] = if bctype == BCODESXP
            readbytecodecontents(bctx)
        elseif bctype ∈ [ BCREPDEF, BCREPDEF, LANGSXP, LISTSXP, ATTRLANGSXP, ATTRLISTSXP ] # FIXME define Set constant
            readbytecodelang(bctx, bctype)
        else
            readitem(bctx.ctx)
        end
    end
    return RList(v)
end

function readbytecodecontents( bctx::BytecodeContext )
    RBytecode( readitem(bctx.ctx),
               readbytecodeconsts(bctx) )
end

function readbytecode( ctx::RDAContext, fl::RDATag )
    @assert fl == BCODESXP
    res = readbytecodecontents( BytecodeContext( ctx, readint32( ctx.io ) ) )
    res.attr = readattrs( ctx, fl )
    return res
end

function readunsupported( ctx::RDAContext, fl::RDATag )
    error( "Reading SEXPREC of type $(sxtype(fl)) ($(SXTypes[sxtype(fl)].name)) is not supported" )
end

"""
    Definition of R type.
"""
immutable SXTypeInfo
    name::UTF8String     # R type name
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
