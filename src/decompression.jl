using CodecZlib, Requires

abstract type ArchiveFormat{S} end

decompressor_stream(::Type{ArchiveFormat{:Gzip}}, io::IOStream) = GzipDecompressorStream(io)

# Handles the case when we are loading a supported archive format but the codec is not loaded
function decompressor_stream(::Type{ArchiveFormat{S}}, io::IOStream) where S
    throw(CodecMissingError(S))
end

# called by __init__() to enable support for optional codecs
function define_optional_decompressor_streams()
    @require CodecBzip2="523fee87-0ab8-5b00-afb7-3ecf72e48cfd" begin
        decompressor_stream(::Type{ArchiveFormat{:Bzip2}}, io::IOStream) = CodecBzip2.Bzip2DecompressorStream(io)
    end
    @require CodecXz="ba30903b-d9e8-5048-a5ec-d1f5b0d4b47b" begin
        decompressor_stream(::Type{ArchiveFormat{:Xz}}, io::IOStream) = CodecXz.XzDecompressorStream(io)
    end
end

# Magic numbers that identify the supported compression formats
const MAGIC_GZIP = b"\x1F\x8B"
const MAGIC_BZIP2 = b"BZh"
const MAGIC_XZ = b"\xFD7zXZ\x00"

function decompress(io)
    # Read the first 6 bytes to obtain the magic number if there is one.
    buffer = zeros(UInt8, 6)
    readbytes!(io, buffer)
    seekstart(io)

    # Check for any of the gzip, bzip2 or xz magic numbers
    if buffer[1:2] == MAGIC_GZIP
        return decompressor_stream(ArchiveFormat{:Gzip}, io)
    elseif buffer[1:3] == MAGIC_BZIP2
        return decompressor_stream(ArchiveFormat{:Bzip2}, io)
    elseif buffer == MAGIC_XZ
        return decompressor_stream(ArchiveFormat{:Xz}, io)
    end

    # If none of the magic numbers match, we assume the file is not compressed

    return io
end
