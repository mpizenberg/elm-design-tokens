module DesignTokens.TokenTree.ResolveTest exposing (suite)

import DesignTokens.Token exposing (TokenValue(..))
import DesignTokens.TokenTree as TokenTree
import DesignTokens.TokenTree.Resolve as Resolve exposing (ResolutionError(..))
import Expect
import Json.Decode as Decode
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "DesignTokens.TokenTree.Resolve"
        [ literalTests
        , typeInheritanceTests
        , aliasTests
        , cycleDetectionTests
        , errorTests
        , rootTests
        , extendsTests
        ]


literalTests : Test
literalTests =
    describe "literal tokens"
        [ test "resolves a single literal token" <|
            \_ ->
                """{"size":{"$type":"dimension","$value":{"value":16,"unit":"px"}}}"""
                    |> parseAndResolve
                    |> Result.map (List.map .path)
                    |> Expect.equal (Ok [ [ "size" ] ])
        , test "resolved token has correct type" <|
            \_ ->
                """{"size":{"$type":"dimension","$value":{"value":16,"unit":"px"}}}"""
                    |> parseAndResolve
                    |> Result.map (List.map .typeName)
                    |> Expect.equal (Ok [ "dimension" ])
        , test "resolves number type" <|
            \_ ->
                """{"ratio":{"$type":"number","$value":1.5}}"""
                    |> parseAndResolve
                    |> Result.map (List.map .value)
                    |> Expect.equal (Ok [ NumberValue 1.5 ])
        , test "resolves string type" <|
            \_ ->
                """{"label":{"$type":"string","$value":"hello"}}"""
                    |> parseAndResolve
                    |> Result.map (List.map .value)
                    |> Expect.equal (Ok [ StringValue "hello" ])
        , test "resolves boolean type" <|
            \_ ->
                """{"flag":{"$type":"boolean","$value":true}}"""
                    |> parseAndResolve
                    |> Result.map (List.map .value)
                    |> Expect.equal (Ok [ BooleanValue True ])
        ]


typeInheritanceTests : Test
typeInheritanceTests =
    describe "type inheritance"
        [ test "inherits $type from parent group" <|
            \_ ->
                """{"sizes":{"$type":"dimension","small":{"$value":{"value":8,"unit":"px"}},"medium":{"$value":{"value":16,"unit":"px"}}}}"""
                    |> parseAndResolve
                    |> Result.map (List.map .typeName)
                    |> Result.map List.sort
                    |> Expect.equal (Ok [ "dimension", "dimension" ])
        , test "token $type overrides group $type" <|
            \_ ->
                """{"stuff":{"$type":"dimension","size":{"$value":{"value":8,"unit":"px"}},"name":{"$type":"string","$value":"hello"}}}"""
                    |> parseAndResolve
                    |> Result.map
                        (List.sortBy (.path >> String.join ".")
                            >> List.map (\t -> ( t.path, t.typeName ))
                        )
                    |> Expect.equal
                        (Ok
                            [ ( [ "stuff", "name" ], "string" )
                            , ( [ "stuff", "size" ], "dimension" )
                            ]
                        )
        , test "inherits $type through nested groups" <|
            \_ ->
                """{"root":{"$type":"dimension","sub":{"deep":{"$value":{"value":4,"unit":"px"}}}}}"""
                    |> parseAndResolve
                    |> Result.map (List.map .typeName)
                    |> Expect.equal (Ok [ "dimension" ])
        ]


aliasTests : Test
aliasTests =
    describe "alias resolution"
        [ test "resolves simple alias" <|
            \_ ->
                """{"a":{"$type":"number","$value":42},"b":{"$type":"number","$value":"{a}"}}"""
                    |> parseAndResolve
                    |> Result.map
                        (List.sortBy (.path >> String.join ".")
                            >> List.map (\t -> ( t.path, t.value ))
                        )
                    |> Expect.equal
                        (Ok
                            [ ( [ "a" ], NumberValue 42 )
                            , ( [ "b" ], NumberValue 42 )
                            ]
                        )
        , test "literal has aliasOf Nothing" <|
            \_ ->
                """{"a":{"$type":"number","$value":42}}"""
                    |> parseAndResolve
                    |> Result.map (List.map .aliasOf)
                    |> Expect.equal (Ok [ Nothing ])
        , test "alias has aliasOf with target path" <|
            \_ ->
                """{"a":{"$type":"number","$value":42},"b":{"$type":"number","$value":"{a}"}}"""
                    |> parseAndResolve
                    |> Result.map
                        (List.sortBy (.path >> String.join ".")
                            >> List.map (\t -> ( t.path, t.aliasOf ))
                        )
                    |> Expect.equal
                        (Ok
                            [ ( [ "a" ], Nothing )
                            , ( [ "b" ], Just [ "a" ] )
                            ]
                        )
        , test "alias chain preserves direct target" <|
            \_ ->
                """{"a":{"$type":"number","$value":42},"b":{"$type":"number","$value":"{a}"},"c":{"$type":"number","$value":"{b}"}}"""
                    |> parseAndResolve
                    |> Result.map
                        (List.sortBy (.path >> String.join ".")
                            >> List.map (\t -> ( t.path, t.aliasOf ))
                        )
                    |> Expect.equal
                        (Ok
                            [ ( [ "a" ], Nothing )
                            , ( [ "b" ], Just [ "a" ] )
                            , ( [ "c" ], Just [ "b" ] )
                            ]
                        )
        , test "resolves alias chain" <|
            \_ ->
                """{"a":{"$type":"number","$value":42},"b":{"$type":"number","$value":"{a}"},"c":{"$type":"number","$value":"{b}"}}"""
                    |> parseAndResolve
                    |> Result.map
                        (List.sortBy (.path >> String.join ".")
                            >> List.map (\t -> ( t.path, t.value ))
                        )
                    |> Expect.equal
                        (Ok
                            [ ( [ "a" ], NumberValue 42 )
                            , ( [ "b" ], NumberValue 42 )
                            , ( [ "c" ], NumberValue 42 )
                            ]
                        )
        , test "resolves alias to nested token" <|
            \_ ->
                """{"sizes":{"$type":"dimension","small":{"$value":{"value":8,"unit":"px"}}},"ref":{"$type":"dimension","$value":"{sizes.small}"}}"""
                    |> parseAndResolve
                    |> Result.map
                        (List.filter (\t -> t.path == [ "ref" ])
                            >> List.map .typeName
                        )
                    |> Expect.equal (Ok [ "dimension" ])
        ]


cycleDetectionTests : Test
cycleDetectionTests =
    describe "cycle detection"
        [ test "detects direct self-reference" <|
            \_ ->
                """{"a":{"$type":"number","$value":"{a}"}}"""
                    |> parseAndResolve
                    |> expectCircularReference
        , test "detects indirect cycle" <|
            \_ ->
                """{"a":{"$type":"number","$value":"{b}"},"b":{"$type":"number","$value":"{a}"}}"""
                    |> parseAndResolve
                    |> expectCircularReference
        , test "detects 3-node cycle" <|
            \_ ->
                """{"a":{"$type":"number","$value":"{b}"},"b":{"$type":"number","$value":"{c}"},"c":{"$type":"number","$value":"{a}"}}"""
                    |> parseAndResolve
                    |> expectCircularReference
        ]


errorTests : Test
errorTests =
    describe "error reporting"
        [ test "MissingType when no type available" <|
            \_ ->
                """{"a":{"$value":42}}"""
                    |> parseAndResolve
                    |> expectErrorType
                        (\err ->
                            case err of
                                MissingType _ ->
                                    True

                                _ ->
                                    False
                        )
        , test "UnknownType for invalid type" <|
            \_ ->
                """{"a":{"$type":"foobar","$value":42}}"""
                    |> parseAndResolve
                    |> expectErrorType
                        (\err ->
                            case err of
                                UnknownType _ "foobar" ->
                                    True

                                _ ->
                                    False
                        )
        , test "DecodeError when value doesn't match type" <|
            \_ ->
                """{"a":{"$type":"dimension","$value":"not-a-dimension"}}"""
                    |> parseAndResolve
                    |> expectErrorType
                        (\err ->
                            case err of
                                DecodeError _ "dimension" _ ->
                                    True

                                _ ->
                                    False
                        )
        , test "UnresolvedAlias for dangling reference" <|
            \_ ->
                """{"a":{"$type":"number","$value":"{nonexistent}"}}"""
                    |> parseAndResolve
                    |> expectErrorType
                        (\err ->
                            case err of
                                UnresolvedAlias _ [ "nonexistent" ] ->
                                    True

                                _ ->
                                    False
                        )
        ]


rootTests : Test
rootTests =
    describe "$root token"
        [ test "$root token is accessible via parent path" <|
            \_ ->
                """{"accent":{"$root":{"$type":"color","$value":{"colorSpace":"srgb","components":[1,0,0]}},"light":{"$type":"color","$value":{"colorSpace":"srgb","components":[1,0.5,0.5]}}}}"""
                    |> parseAndResolve
                    |> Result.map
                        (List.map .path >> List.sort)
                    |> Expect.equal
                        (Ok
                            [ [ "accent" ]
                            , [ "accent", "$root" ]
                            , [ "accent", "light" ]
                            ]
                        )
        , test "alias to $root via group path" <|
            \_ ->
                """{"accent":{"$root":{"$type":"color","$value":{"colorSpace":"srgb","components":[1,0,0]}},"light":{"$type":"color","$value":{"colorSpace":"srgb","components":[1,0.5,0.5]}}},"ref":{"$type":"color","$value":"{accent}"}}"""
                    |> parseAndResolve
                    |> Result.map
                        (List.filter (\t -> t.path == [ "ref" ])
                            >> List.map .typeName
                        )
                    |> Expect.equal (Ok [ "color" ])
        ]


extendsTests : Test
extendsTests =
    describe "$extends resolution"
        [ test "inherits tokens from target group" <|
            \_ ->
                """{"base":{"$type":"number","a":{"$value":1}},"derived":{"$extends":"{base}","b":{"$type":"number","$value":2}}}"""
                    |> parseAndResolve
                    |> Result.map
                        (List.map .path >> List.sort)
                    |> Expect.equal
                        (Ok
                            [ [ "base", "a" ]
                            , [ "derived", "a" ]
                            , [ "derived", "b" ]
                            ]
                        )
        , test "override wins over base" <|
            \_ ->
                """{"base":{"$type":"number","x":{"$value":1}},"derived":{"$extends":"{base}","x":{"$type":"number","$value":99}}}"""
                    |> parseAndResolve
                    |> Result.map
                        (List.filter (\t -> t.path == [ "derived", "x" ])
                            >> List.map .value
                        )
                    |> Expect.equal (Ok [ NumberValue 99 ])
        , test "inherits $type from target group" <|
            \_ ->
                """{"base":{"$type":"number","x":{"$value":1}},"derived":{"$extends":"{base}","y":{"$value":2}}}"""
                    |> parseAndResolve
                    |> Result.map
                        (List.filter (\t -> t.path == [ "derived", "y" ])
                            >> List.map .typeName
                        )
                    |> Expect.equal (Ok [ "number" ])
        , test "deep merge of nested groups" <|
            \_ ->
                """{"base":{"sub":{"$type":"number","a":{"$value":1}}},"derived":{"$extends":"{base}","sub":{"b":{"$type":"number","$value":2}}}}"""
                    |> parseAndResolve
                    |> Result.map
                        (List.map .path >> List.sort)
                    |> Expect.equal
                        (Ok
                            [ [ "base", "sub", "a" ]
                            , [ "derived", "sub", "a" ]
                            , [ "derived", "sub", "b" ]
                            ]
                        )
        , test "chained extends (A extends B extends C)" <|
            \_ ->
                """{"c":{"$type":"number","x":{"$value":1}},"b":{"$extends":"{c}","y":{"$type":"number","$value":2}},"a":{"$extends":"{b}","z":{"$type":"number","$value":3}}}"""
                    |> parseAndResolve
                    |> Result.map
                        (List.filter (\t -> List.head t.path == Just "a")
                            >> List.map .path
                            >> List.sort
                        )
                    |> Expect.equal
                        (Ok
                            [ [ "a", "x" ]
                            , [ "a", "y" ]
                            , [ "a", "z" ]
                            ]
                        )
        , test "target not found" <|
            \_ ->
                """{"derived":{"$extends":"{nonexistent}","a":{"$type":"number","$value":1}}}"""
                    |> parseAndResolve
                    |> expectErrorType
                        (\err ->
                            case err of
                                ExtendsTargetNotFound _ [ "nonexistent" ] ->
                                    True

                                _ ->
                                    False
                        )
        , test "circular extends" <|
            \_ ->
                """{"a":{"$extends":"{b}","x":{"$type":"number","$value":1}},"b":{"$extends":"{a}","y":{"$type":"number","$value":2}}}"""
                    |> parseAndResolve
                    |> expectErrorType
                        (\err ->
                            case err of
                                CircularExtends _ ->
                                    True

                                _ ->
                                    False
                        )
        , test "extends with dotted path to nested group" <|
            \_ ->
                """{"themes":{"light":{"$type":"color","bg":{"$value":{"colorSpace":"srgb","components":[1,1,1]}}}},"dark":{"$extends":"{themes.light}","bg":{"$type":"color","$value":{"colorSpace":"srgb","components":[0,0,0]}}}}"""
                    |> parseAndResolve
                    |> Result.map
                        (List.filter (\t -> List.head t.path == Just "dark")
                            >> List.map .path
                        )
                    |> Expect.equal (Ok [ [ "dark", "bg" ] ])
        ]



-- HELPERS


parseAndResolve : String -> Result (List ResolutionError) (List DesignTokens.Token.ResolvedToken)
parseAndResolve jsonStr =
    case Decode.decodeString Decode.value jsonStr of
        Err err ->
            Err [ DecodeError [] "" (Decode.errorToString err) ]

        Ok val ->
            case TokenTree.fromJson val of
                Err _ ->
                    Err [ DecodeError [] "" "parse error" ]

                Ok tree ->
                    Resolve.resolve tree


expectCircularReference : Result (List ResolutionError) a -> Expect.Expectation
expectCircularReference result =
    case result of
        Err errors ->
            if List.any isCircularReference errors then
                Expect.pass

            else
                Expect.fail ("Expected CircularReference error, got: " ++ Debug.toString errors)

        Ok _ ->
            Expect.fail "Expected error but got Ok"


isCircularReference : ResolutionError -> Bool
isCircularReference err =
    case err of
        CircularReference _ ->
            True

        _ ->
            False


expectErrorType : (ResolutionError -> Bool) -> Result (List ResolutionError) a -> Expect.Expectation
expectErrorType predicate result =
    case result of
        Err errors ->
            if List.any predicate errors then
                Expect.pass

            else
                Expect.fail ("Expected matching error, got: " ++ Debug.toString errors)

        Ok _ ->
            Expect.fail "Expected error but got Ok"
