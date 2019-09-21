module TestErrors
    using RData, Test

    @testset "Custom errors" begin
        @testset "CodecMissingError" begin
            err = CodecMissingError(:Xz)
            @test err isa RDataException

            io = IOBuffer()
            showerror(io, err)
            msg = String(take!(io))

            @test startswith(msg, "CodecMissingError: CodecXz package is required")
        end
    end
end
