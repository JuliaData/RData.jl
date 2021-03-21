abstract type RDataException <: Exception end

struct UnsupportedROBJ <: RDataException
    sxtype::SXType
    msg::String

    UnsupportedROBJ(sxtype::SXType, msg::AbstractString) = new(sxtype, msg)
    UnsupportedROBJ(sxtype::SXType) =
        UnsupportedROBJ(sxtype, "Unsupported R object (sxtype=$(sxtype))")
end

Base.showerror(io::IO, e::UnsupportedROBJ) = print(io, e.msg)

struct CodecMissingError <: RDataException
    formatName::Symbol
end

function Base.showerror(io::IO, e::CodecMissingError)
    codecpkg = "Codec" * titlecase(String(e.formatName))
    print(io, string(
        "$(typeof(e)): $codecpkg package is required to read ",
        "$(e.formatName)-compressed RData files. Run ",
        "Pkg.add(\"$codecpkg\") to install it. Then in your code call ",
        "\"using $codecpkg\" before \"using RData\"."
    ))
end
