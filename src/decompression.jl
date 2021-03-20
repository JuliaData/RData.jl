using CodecZlib, Requires

abstract type ArchiveFormat{S} end

decompressor_stream(::Type{ArchiveFormat{:GZIP}}, io::IOStream) = GzipDecompressorStream(io)

# Handles the case when we are loading a supported archive format but the codec is not loaded
function decompressor_stream(::Type{ArchiveFormat{S}}, io::IOStream) where S
    throw(CodecMissingError(S))
end

# called by __init__() to enable support for optional codecs
function define_optional_decompressor_streams()
    @require CodecBzip2="523fee87-0ab8-5b00-afb7-3ecf72e48cfd" begin
        decompressor_stream(::Type{ArchiveFormat{:BZIP2}}, io::IOStream) = CodecBzip2.Bzip2DecompressorStream(io)
    end
    @require CodecXz="ba30903b-d9e8-5048-a5ec-d1f5b0d4b47b" begin
        decompressor_stream(::Type{ArchiveFormat{:XZ}}, io::IOStream) = CodecXz.XzDecompressorStream(io)
    end
end

# decompress the stream if it's compressed (by a supported codec)
function decompress(io)
    format = FileIO.detect_compressor(io, formats=["GZIP", "BZIP2", "XZ"])
    if format !== nothing
        return decompressor_stream(ArchiveFormat{Symbol(format)}, io)
    else
        return io # not compressed
    end
end
