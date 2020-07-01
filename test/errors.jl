module TestErrors
    using RData, Test

    @testset "Custom errors" begin
        @testset "UnsupportedROBJ" begin
            err = UnsupportedROBJ(RData.S4SXP)
            @test err isa RDataException
            @test err.sxtype == RData.S4SXP

            io = IOBuffer()
            showerror(io, err)
            msg = String(take!(io))

            @test startswith(msg, "Unsupported R object")
        end

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
