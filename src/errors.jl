abstract type RDataException <: Exception end

struct CodecMissingError <: RDataException
    formatName::Symbol
end

function Base.showerror(io::IO, e::CodecMissingError)
  print(io, string(
    "$(typeof(e)): Codec$(e.formatName) package is required to read ",
    "$(e.formatName)-compressed RData files. Run ",
    "Pkg.add(\"Codec$(e.formatName)\") to install it. Then in your code call ",
    "\"using Codec$(e.formatName)\" before \"using RData\"."
  ))
end
