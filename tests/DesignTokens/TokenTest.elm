module DesignTokens.TokenTest exposing (suite)

import DesignTokens.Dimension as Dimension
import DesignTokens.Token as Token exposing (TokenValue(..))
import Expect
import Json.Decode as Decode
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "DesignTokens.Token"
        [ decoderDispatchTests
        , unknownTypeTest
        , toCssStringTests
        , typeNameTests
        , roundTripTests
        , deprecatedTests
        ]


decoderDispatchTests : Test
decoderDispatchTests =
    describe "tokenValueDecoder dispatches"
        [ test "color" <|
            \_ ->
                """{"colorSpace":"srgb","components":[1,0,0]}"""
                    |> Decode.decodeString (Token.tokenValueDecoder "color")
                    |> Result.map Token.tokenTypeName
                    |> Expect.equal (Ok "color")
        , test "dimension" <|
            \_ ->
                """{"value":16,"unit":"px"}"""
                    |> Decode.decodeString (Token.tokenValueDecoder "dimension")
                    |> Result.map Token.tokenTypeName
                    |> Expect.equal (Ok "dimension")
        , test "fontFamily" <|
            \_ ->
                """["Helvetica","Arial"]"""
                    |> Decode.decodeString (Token.tokenValueDecoder "fontFamily")
                    |> Result.map Token.tokenTypeName
                    |> Expect.equal (Ok "fontFamily")
        , test "fontWeight" <|
            \_ ->
                "700"
                    |> Decode.decodeString (Token.tokenValueDecoder "fontWeight")
                    |> Result.map Token.tokenTypeName
                    |> Expect.equal (Ok "fontWeight")
        , test "duration" <|
            \_ ->
                """{"value":200,"unit":"ms"}"""
                    |> Decode.decodeString (Token.tokenValueDecoder "duration")
                    |> Result.map Token.tokenTypeName
                    |> Expect.equal (Ok "duration")
        , test "cubicBezier" <|
            \_ ->
                "[0.5,0,1,1]"
                    |> Decode.decodeString (Token.tokenValueDecoder "cubicBezier")
                    |> Result.map Token.tokenTypeName
                    |> Expect.equal (Ok "cubicBezier")
        , test "number" <|
            \_ ->
                "42.5"
                    |> Decode.decodeString (Token.tokenValueDecoder "number")
                    |> Expect.equal (Ok (NumberValue 42.5))
        , test "string" <|
            \_ ->
                "\"hello\""
                    |> Decode.decodeString (Token.tokenValueDecoder "string")
                    |> Expect.equal (Ok (StringValue "hello"))
        , test "boolean" <|
            \_ ->
                "true"
                    |> Decode.decodeString (Token.tokenValueDecoder "boolean")
                    |> Expect.equal (Ok (BooleanValue True))
        , test "shadow" <|
            \_ ->
                """{"color":{"colorSpace":"srgb","components":[0,0,0]},"offsetX":{"value":2,"unit":"px"},"offsetY":{"value":4,"unit":"px"},"blur":{"value":8,"unit":"px"},"spread":{"value":0,"unit":"px"}}"""
                    |> Decode.decodeString (Token.tokenValueDecoder "shadow")
                    |> Result.map Token.tokenTypeName
                    |> Expect.equal (Ok "shadow")
        , test "border" <|
            \_ ->
                """{"color":{"colorSpace":"srgb","components":[0,0,0]},"width":{"value":1,"unit":"px"},"style":"solid"}"""
                    |> Decode.decodeString (Token.tokenValueDecoder "border")
                    |> Result.map Token.tokenTypeName
                    |> Expect.equal (Ok "border")
        , test "strokeStyle" <|
            \_ ->
                "\"dashed\""
                    |> Decode.decodeString (Token.tokenValueDecoder "strokeStyle")
                    |> Result.map Token.tokenTypeName
                    |> Expect.equal (Ok "strokeStyle")
        , test "gradient" <|
            \_ ->
                """[{"color":{"colorSpace":"srgb","components":[1,0,0]},"position":0}]"""
                    |> Decode.decodeString (Token.tokenValueDecoder "gradient")
                    |> Result.map Token.tokenTypeName
                    |> Expect.equal (Ok "gradient")
        , test "typography" <|
            \_ ->
                """{"fontFamily":"Helvetica","fontSize":{"value":16,"unit":"px"},"fontWeight":"normal","lineHeight":1.5}"""
                    |> Decode.decodeString (Token.tokenValueDecoder "typography")
                    |> Result.map Token.tokenTypeName
                    |> Expect.equal (Ok "typography")
        , test "transition" <|
            \_ ->
                """{"duration":{"value":200,"unit":"ms"},"timingFunction":[0.5,0,1,1]}"""
                    |> Decode.decodeString (Token.tokenValueDecoder "transition")
                    |> Result.map Token.tokenTypeName
                    |> Expect.equal (Ok "transition")
        ]


unknownTypeTest : Test
unknownTypeTest =
    describe "unknown type"
        [ test "fails on unknown type name" <|
            \_ ->
                "42"
                    |> Decode.decodeString (Token.tokenValueDecoder "unknown")
                    |> Expect.err
        ]


toCssStringTests : Test
toCssStringTests =
    describe "tokenValueToCssString"
        [ test "number" <|
            \_ ->
                Token.tokenValueToCssString (NumberValue 42.5)
                    |> Expect.equal "42.5"
        , test "string" <|
            \_ ->
                Token.tokenValueToCssString (StringValue "hello")
                    |> Expect.equal "hello"
        , test "boolean true" <|
            \_ ->
                Token.tokenValueToCssString (BooleanValue True)
                    |> Expect.equal "true"
        , test "boolean false" <|
            \_ ->
                Token.tokenValueToCssString (BooleanValue False)
                    |> Expect.equal "false"
        , test "dimension" <|
            \_ ->
                Token.tokenValueToCssString (DimensionValue (Dimension.px 16))
                    |> Expect.equal "16px"
        ]


typeNameTests : Test
typeNameTests =
    describe "tokenTypeName"
        [ test "number" <|
            \_ ->
                Token.tokenTypeName (NumberValue 0)
                    |> Expect.equal "number"
        , test "string" <|
            \_ ->
                Token.tokenTypeName (StringValue "")
                    |> Expect.equal "string"
        , test "boolean" <|
            \_ ->
                Token.tokenTypeName (BooleanValue True)
                    |> Expect.equal "boolean"
        ]


roundTripTests : Test
roundTripTests =
    describe "round-trip"
        [ test "number round-trips" <|
            \_ ->
                let
                    val : TokenValue
                    val =
                        NumberValue 3.14
                in
                Token.encodeTokenValue val
                    |> Decode.decodeValue (Token.tokenValueDecoder "number")
                    |> Expect.equal (Ok val)
        , test "string round-trips" <|
            \_ ->
                let
                    val : TokenValue
                    val =
                        StringValue "test"
                in
                Token.encodeTokenValue val
                    |> Decode.decodeValue (Token.tokenValueDecoder "string")
                    |> Expect.equal (Ok val)
        , test "boolean round-trips" <|
            \_ ->
                let
                    val : TokenValue
                    val =
                        BooleanValue False
                in
                Token.encodeTokenValue val
                    |> Decode.decodeValue (Token.tokenValueDecoder "boolean")
                    |> Expect.equal (Ok val)
        , test "dimension round-trips" <|
            \_ ->
                let
                    val : TokenValue
                    val =
                        DimensionValue (Dimension.px 16)
                in
                Token.encodeTokenValue val
                    |> Decode.decodeValue (Token.tokenValueDecoder "dimension")
                    |> Expect.equal (Ok val)
        ]


deprecatedTests : Test
deprecatedTests =
    describe "deprecated"
        [ test "decodes boolean" <|
            \_ ->
                "true"
                    |> Decode.decodeString Token.deprecatedDecoder
                    |> Expect.equal (Ok (Token.DeprecatedBool True))
        , test "decodes string" <|
            \_ ->
                "\"Use primary-color instead\""
                    |> Decode.decodeString Token.deprecatedDecoder
                    |> Expect.equal (Ok (Token.DeprecatedMessage "Use primary-color instead"))
        , test "round-trips bool" <|
            \_ ->
                Token.DeprecatedBool True
                    |> Token.encodeDeprecated
                    |> Decode.decodeValue Token.deprecatedDecoder
                    |> Expect.equal (Ok (Token.DeprecatedBool True))
        , test "round-trips string" <|
            \_ ->
                Token.DeprecatedMessage "old"
                    |> Token.encodeDeprecated
                    |> Decode.decodeValue Token.deprecatedDecoder
                    |> Expect.equal (Ok (Token.DeprecatedMessage "old"))
        ]
