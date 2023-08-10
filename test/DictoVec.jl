module TestDictoVec
using Test
using RData

function show2string(dv::DictoVec)
    iob = IOBuffer()
    show(iob, dv)
    return String(take!(iob))
end

@testset "RData DictoVec type" begin

@testset "Empty DictoVec" begin
    @test_throws MethodError DictoVec(Symbol[], [:a])
    @test_throws DimensionMismatch DictoVec(Symbol[], ["a"])
    dv = DictoVec(Symbol[])

    @test typeof(dv) === DictoVec{Symbol}
    @test eltype(dv) === Symbol
    @test dv isa AbstractVector{Symbol}
    @test length(dv) == 0
    @test size(dv) == (0,)
    @test isempty(dv)
    @test collect(keys(dv)) == RData.RString[]
    @test values(dv) == Symbol[]
    @test !haskey(dv, "a")
    @test !haskey(dv, :a)
    @test !haskey(dv, 1)
    @test_throws BoundsError dv[1]
    @test_throws KeyError dv["a"]
    @test_throws KeyError dv[:a]

    @test dv == DictoVec(Symbol[]) == DictoVec(Int[])
    @test isequal(dv, DictoVec(Symbol[]))
    @test isequal(dv, DictoVec(Int[]))
    @test dv != DictoVec([:a], ["a"])
    @test !isequal(dv, DictoVec([:a], ["a"]))
    @test hash(dv) == hash(DictoVec(Symbol[])) == hash(DictoVec(Int[]))

    @test get(dv, 1, :x) == :x
    @test get(() -> :y, dv, 1) == :y
    @test get(dv, "a", :x) == :x
    @test get(() -> :y, dv, "a") == :y
    @test length(dv) == 0

    @test convert(Dict{RData.RString, Any}, dv) == Dict{RData.RString, Any}()

    @test show2string(dv) == "DictoVec{Symbol}()"

    # add an element
    @test_throws MethodError (dv[1] = "xx") # incompatible value
    @test length(dv) == 0
    @test_throws BoundsError (dv[1] = :xx) # cannot create new elements by integer index
    @test length(dv) == 0
    @test_throws MethodError (dv[:a] = "xx") # incompatible key
    @test length(dv) == 0
    @test_throws MethodError (dv["a"] = "xx") # incompatible value
    @test length(dv) == 0
    dv["a"] = :xx
    @test !isempty(dv)
    @test length(dv) == 1
    @test haskey(dv, "a")
    @test dv["a"] == :xx
    @test dv[1] == :xx
    @test collect(keys(dv)) == ["a"]
    @test values(dv) == [:xx]

    @test show2string(dv) == "DictoVec{Symbol}(\"a\"=>:xx)"

    # reassign element
    dv[1] = :yy
    @test length(dv) == 1
    @test dv[1] == :yy
    @test dv["a"] == :yy

    # deleting an element by key
    @test delete!(dv, 1) === dv
    @test length(dv) == 1
    delete!(dv, "b")
    @test length(dv) == 1
    delete!(dv, "a")
    @test length(dv) == 0
    @test !haskey(dv, "a")
    @test_throws BoundsError dv[1]
end

@testset "Nameless DictoVec" begin
    dv = DictoVec([2.0, 5.0, 4.0])
    @test typeof(dv) === DictoVec{Float64}
    @test dv isa AbstractVector{Float64}
    @test eltype(dv) === Float64
    @test length(dv) == 3
    @test size(dv) == (3,)
    @test !isempty(dv)
    @test !haskey(dv, 1)
    @test !haskey(dv, "a")
    @test !haskey(dv, :a)
    @test show2string(dv) == "DictoVec{Float64}(2.0,5.0,4.0)"
    @test collect(keys(dv)) == RData.RString[]
    @test values(dv) == [2.0, 5.0, 4.0]

    @test dv == DictoVec([2.0, 5.0, 4.0])
    @test dv == DictoVec([2, 5, 4])
    @test dv == DictoVec([2, 5, 4], String[])
    @test isequal(dv, DictoVec([2.0, 5.0, 4.0]))
    @test dv != DictoVec([3.0, 5.0, 4.0])
    @test !isequal(dv, DictoVec([3.0, 5.0, 4.0]))
    @test dv != DictoVec([2.0, 5.0, 4.0], ["b", "c", "a"])
    @test !isequal(dv, DictoVec([2.0, 5.0, 4.0], ["b", "c", "a"]))
    @test hash(dv) ==
        hash(DictoVec([2.0, 5.0, 4.0])) ==
        hash(DictoVec([2, 5, 4]))

    @test_throws BoundsError dv[0]
    @test_throws BoundsError dv[4]
    @test dv[1] == 2.0
    @test dv[[1, 3]] == [2.0, 4.0]
    @test_throws KeyError dv["a"]
    @test_throws KeyError dv[:a]

    # add new element by name
    dv["a"] = 3
    @test haskey(dv, "a")
    @test length(dv) == 4
    @test dv["a"] === 3.0
    @test dv[4] === 3.0
    @test show2string(dv) == "DictoVec{Float64}(2.0,5.0,4.0,\"a\"=>3.0)"

    @test delete!(dv, "a") === dv
    @test length(dv) == 3
    @test !haskey(dv, "a")
end

@testset "DictoVec with names" begin
    dv = DictoVec([2.0, 5.0, 4.0], ["a", "b", "c"])
    @test typeof(dv) === DictoVec{Float64}
    @test dv isa AbstractVector{Float64}
    @test eltype(dv) === Float64
    @test length(dv) == 3
    @test size(dv) == (3,)
    @test !isempty(dv)
    @test !haskey(dv, 1)
    @test haskey(dv, "a")
    @test !haskey(dv, :a)
    @test sort!(collect(keys(dv))) == ["a", "b", "c"]
    @test values(dv) == [2.0, 5.0, 4.0]
    @test show2string(dv) == "DictoVec{Float64}(\"a\"=>2.0,\"b\"=>5.0,\"c\"=>4.0)"

    @test dv == DictoVec([2.0, 5.0, 4.0], ["a", "b", "c"])
    @test dv == DictoVec([2, 5, 4], ["a", "b", "c"])
    @test isequal(dv, DictoVec([2.0, 5.0, 4.0], ["a", "b", "c"]))
    @test dv != DictoVec([3.0, 5.0, 4.0], ["a", "b", "c"])
    @test !isequal(dv, DictoVec([3.0, 5.0, 4.0], ["a", "b", "c"]))
    @test dv != DictoVec([2.0, 5.0, 4.0], ["b", "c", "a"])
    @test !isequal(dv, DictoVec([2.0, 5.0, 4.0], ["b", "c", "a"]))
    @test hash(dv) ==
        hash(DictoVec([2.0, 5.0, 4.0], ["a", "b", "c"])) ==
        hash(DictoVec([2, 5, 4], ["a", "b", "c"]))

    @test dv[1] === 2.0
    @test dv["a"] === 2.0
    @test dv[[1, 3]] == [2.0, 4.0]
    @test_throws KeyError dv[:a]

    # reassign element by name
    dv["a"] = 6
    @test haskey(dv, "a")
    @test length(dv) == 3
    @test dv["a"] === 6.0
    @test dv[1] === 6.0
    @test show2string(dv) == "DictoVec{Float64}(\"a\"=>6.0,\"b\"=>5.0,\"c\"=>4.0)"

    # deleting an element from the middle
    @test delete!(dv, "b") === dv
    @test length(dv) == 2
    @test !haskey(dv, "b")
    @test dv[2] == 4.0 # indices has updated
    @test show2string(dv) == "DictoVec{Float64}(\"a\"=>6.0,\"c\"=>4.0)"
end

@testset "== and isequal with -0.0, NaN and missing" begin
    @test DictoVec([0.0, 5.0, 4.0], ["b", "c", "a"]) ==
        DictoVec([-0.0, 5.0, 4.0], ["b", "c", "a"])
    @test !isequal(DictoVec([0.0, 5.0, 4.0], ["b", "c", "a"]),
        DictoVec([-0.0, 5.0, 4.0], ["b", "c", "a"]))

    @test DictoVec([NaN, 5.0, 4.0], ["b", "c", "a"]) !=
        DictoVec([NaN, 5.0, 4.0], ["b", "c", "a"])
    @test isequal(DictoVec([NaN, 5.0, 4.0], ["b", "c", "a"]),
        DictoVec([NaN, 5.0, 4.0], ["b", "c", "a"]))

    @test ismissing(DictoVec([missing, 5.0, 4.0], ["b", "c", "a"]) !=
                    DictoVec([missing, 5.0, 4.0], ["b", "c", "a"]))
    @test isequal(DictoVec([missing, 5.0, 4.0], ["b", "c", "a"]),
        DictoVec([missing, 5.0, 4.0], ["b", "c", "a"]))
end

end

end # TestDictoVec
