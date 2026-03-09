module DesignTokens.TokenTreeTest exposing (suite)

import DesignTokens.Token exposing (Deprecated(..))
import DesignTokens.TokenTree as TokenTree exposing (Error(..), TokenTree(..), TreeNode(..), ValueOrAlias(..))
import Dict
import Expect
import Json.Decode as Decode
import Json.Encode as Encode
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "DesignTokens.TokenTree"
        [ parseTests
        , aliasDetectionTests
        , nameValidationTests
        , metadataTests
        , groupTests
        ]


parseTests : Test
parseTests =
    describe "fromJson"
        [ test "parses a single token" <|
            \_ ->
                """{"brand":{"$type":"color","$value":{"colorSpace":"srgb","components":[1,0,0]}}}"""
                    |> decodeAndParse
                    |> Result.map (\(TokenTree g) -> Dict.keys g.children)
                    |> Expect.equal (Ok [ "brand" ])
        , test "token node has correct type" <|
            \_ ->
                """{"brand":{"$type":"color","$value":{"colorSpace":"srgb","components":[1,0,0]}}}"""
                    |> decodeAndParse
                    |> Result.map
                        (\(TokenTree g) ->
                            case Dict.get "brand" g.children of
                                Just (TokenNode t) ->
                                    t.type_

                                _ ->
                                    Nothing
                        )
                    |> Expect.equal (Ok (Just "color"))
        , test "parses nested groups" <|
            \_ ->
                """{"colors":{"primary":{"$type":"color","$value":{"colorSpace":"srgb","components":[1,0,0]}}}}"""
                    |> decodeAndParse
                    |> Result.map
                        (\(TokenTree g) ->
                            case Dict.get "colors" g.children of
                                Just (GroupNode sub) ->
                                    Dict.keys sub.children

                                _ ->
                                    []
                        )
                    |> Expect.equal (Ok [ "primary" ])
        , test "group inherits $type" <|
            \_ ->
                """{"colors":{"$type":"color","primary":{"$value":{"colorSpace":"srgb","components":[1,0,0]}}}}"""
                    |> decodeAndParse
                    |> Result.map
                        (\(TokenTree g) ->
                            case Dict.get "colors" g.children of
                                Just (GroupNode sub) ->
                                    sub.type_

                                _ ->
                                    Nothing
                        )
                    |> Expect.equal (Ok (Just "color"))
        , test "empty object parses as empty group" <|
            \_ ->
                "{}"
                    |> decodeAndParse
                    |> Result.map (\(TokenTree g) -> Dict.isEmpty g.children)
                    |> Expect.equal (Ok True)
        , test "fails on non-object JSON" <|
            \_ ->
                "42"
                    |> decodeAndParse
                    |> Expect.err
        ]


aliasDetectionTests : Test
aliasDetectionTests =
    describe "alias detection"
        [ test "detects alias string" <|
            \_ ->
                """{"ref":{"$type":"color","$value":"{colors.primary}"}}"""
                    |> decodeAndParse
                    |> Result.map
                        (\(TokenTree g) ->
                            case Dict.get "ref" g.children of
                                Just (TokenNode t) ->
                                    t.value

                                _ ->
                                    Literal Encode.null
                        )
                    |> Expect.equal (Ok (Alias [ "colors", "primary" ]))
        , test "literal string is not an alias" <|
            \_ ->
                """{"name":{"$type":"string","$value":"hello"}}"""
                    |> decodeAndParse
                    |> Result.map
                        (\(TokenTree g) ->
                            case Dict.get "name" g.children of
                                Just (TokenNode t) ->
                                    case t.value of
                                        Literal _ ->
                                            True

                                        Alias _ ->
                                            False

                                _ ->
                                    False
                        )
                    |> Expect.equal (Ok True)
        , test "object value is literal" <|
            \_ ->
                """{"size":{"$type":"dimension","$value":{"value":16,"unit":"px"}}}"""
                    |> decodeAndParse
                    |> Result.map
                        (\(TokenTree g) ->
                            case Dict.get "size" g.children of
                                Just (TokenNode t) ->
                                    case t.value of
                                        Literal _ ->
                                            True

                                        Alias _ ->
                                            False

                                _ ->
                                    False
                        )
                    |> Expect.equal (Ok True)
        ]


nameValidationTests : Test
nameValidationTests =
    describe "name validation"
        [ test "$ prefix keys are treated as reserved properties and skipped" <|
            \_ ->
                """{"$foo":{"$value":42,"$type":"number"}}"""
                    |> decodeAndParse
                    |> Result.map (\(TokenTree g) -> Dict.isEmpty g.children)
                    |> Expect.equal (Ok True)
        , test "rejects name containing ." <|
            \_ ->
                """{"a.b":{"$value":42,"$type":"number"}}"""
                    |> decodeAndParse
                    |> Expect.err
        , test "rejects name containing {" <|
            \_ ->
                """{"a{b":{"$value":42,"$type":"number"}}"""
                    |> decodeAndParse
                    |> Expect.err
        , test "rejects name containing }" <|
            \_ ->
                """{"a}b":{"$value":42,"$type":"number"}}"""
                    |> decodeAndParse
                    |> Expect.err
        , test "accepts valid name with hyphens" <|
            \_ ->
                """{"brand-color":{"$value":42,"$type":"number"}}"""
                    |> decodeAndParse
                    |> Result.map (\(TokenTree g) -> Dict.keys g.children)
                    |> Expect.equal (Ok [ "brand-color" ])
        ]


metadataTests : Test
metadataTests =
    describe "metadata"
        [ test "preserves $description" <|
            \_ ->
                """{"brand":{"$type":"color","$value":{"colorSpace":"srgb","components":[1,0,0]},"$description":"Primary"}}"""
                    |> decodeAndParse
                    |> Result.map
                        (\(TokenTree g) ->
                            case Dict.get "brand" g.children of
                                Just (TokenNode t) ->
                                    t.description

                                _ ->
                                    Nothing
                        )
                    |> Expect.equal (Ok (Just "Primary"))
        , test "preserves $deprecated boolean" <|
            \_ ->
                """{"old":{"$type":"number","$value":42,"$deprecated":true}}"""
                    |> decodeAndParse
                    |> Result.map
                        (\(TokenTree g) ->
                            case Dict.get "old" g.children of
                                Just (TokenNode t) ->
                                    t.deprecated

                                _ ->
                                    Nothing
                        )
                    |> Expect.equal (Ok (Just (DeprecatedBool True)))
        , test "preserves $deprecated string" <|
            \_ ->
                """{"old":{"$type":"number","$value":42,"$deprecated":"Use new-token"}}"""
                    |> decodeAndParse
                    |> Result.map
                        (\(TokenTree g) ->
                            case Dict.get "old" g.children of
                                Just (TokenNode t) ->
                                    t.deprecated

                                _ ->
                                    Nothing
                        )
                    |> Expect.equal (Ok (Just (DeprecatedMessage "Use new-token")))
        , test "preserves $extensions" <|
            \_ ->
                """{"brand":{"$type":"number","$value":42,"$extensions":{"com.example.meta":true}}}"""
                    |> decodeAndParse
                    |> Result.map
                        (\(TokenTree g) ->
                            case Dict.get "brand" g.children of
                                Just (TokenNode t) ->
                                    t.extensions /= Nothing

                                _ ->
                                    False
                        )
                    |> Expect.equal (Ok True)
        ]


groupTests : Test
groupTests =
    describe "group metadata"
        [ test "group $description is preserved" <|
            \_ ->
                """{"colors":{"$description":"All brand colors","primary":{"$type":"color","$value":{"colorSpace":"srgb","components":[1,0,0]}}}}"""
                    |> decodeAndParse
                    |> Result.map
                        (\(TokenTree g) ->
                            case Dict.get "colors" g.children of
                                Just (GroupNode sub) ->
                                    sub.description

                                _ ->
                                    Nothing
                        )
                    |> Expect.equal (Ok (Just "All brand colors"))
        , test "group $deprecated is preserved" <|
            \_ ->
                """{"old-colors":{"$deprecated":true,"primary":{"$type":"color","$value":{"colorSpace":"srgb","components":[1,0,0]}}}}"""
                    |> decodeAndParse
                    |> Result.map
                        (\(TokenTree g) ->
                            case Dict.get "old-colors" g.children of
                                Just (GroupNode sub) ->
                                    sub.deprecated

                                _ ->
                                    Nothing
                        )
                    |> Expect.equal (Ok (Just (DeprecatedBool True)))
        ]



-- HELPERS


decodeAndParse : String -> Result (List Error) TokenTree
decodeAndParse jsonStr =
    case Decode.decodeString Decode.value jsonStr of
        Ok val ->
            TokenTree.fromJson val

        Err err ->
            Err [ InvalidJson (Decode.errorToString err) ]
