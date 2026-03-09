module DesignTokens.DimensionTest exposing (suite)

import DesignTokens.Dimension as Dimension exposing (DimensionUnit(..), px, rem)
import DesignTokens.Fuzzers as Fuzzers
import Expect
import Json.Decode as Decode
import Json.Encode as Encode
import Test exposing (Test, describe, fuzz, test)


suite : Test
suite =
    describe "DesignTokens.Dimension"
        [ decoderTests
        , encoderTests
        , roundTripTests
        , cssTests
        ]


decoderTests : Test
decoderTests =
    describe "decoder"
        [ test "decodes px" <|
            \_ ->
                """{ "value": 16, "unit": "px" }"""
                    |> Decode.decodeString Dimension.decoder
                    |> Expect.equal (Ok { value = 16, unit = Px })
        , test "decodes rem" <|
            \_ ->
                """{ "value": 1.5, "unit": "rem" }"""
                    |> Decode.decodeString Dimension.decoder
                    |> Expect.equal (Ok { value = 1.5, unit = Rem })
        , test "fails on unknown unit" <|
            \_ ->
                """{ "value": 10, "unit": "em" }"""
                    |> Decode.decodeString Dimension.decoder
                    |> Expect.err
        ]


encoderTests : Test
encoderTests =
    describe "encode"
        [ test "encodes px" <|
            \_ ->
                px 16
                    |> Dimension.encode
                    |> Encode.encode 0
                    |> Expect.equal """{"value":16,"unit":"px"}"""
        , test "encodes rem" <|
            \_ ->
                rem 1.5
                    |> Dimension.encode
                    |> Encode.encode 0
                    |> Expect.equal """{"value":1.5,"unit":"rem"}"""
        ]


roundTripTests : Test
roundTripTests =
    describe "round-trip"
        [ fuzz Fuzzers.dimension "encode >> decode is identity" <|
            \dim ->
                dim
                    |> Dimension.encode
                    |> Decode.decodeValue Dimension.decoder
                    |> Expect.equal (Ok dim)
        ]


cssTests : Test
cssTests =
    describe "toCssString"
        [ test "px" <|
            \_ -> Dimension.toCssString (px 16) |> Expect.equal "16px"
        , test "rem" <|
            \_ -> Dimension.toCssString (rem 1.5) |> Expect.equal "1.5rem"
        , test "zero" <|
            \_ -> Dimension.toCssString (px 0) |> Expect.equal "0px"
        ]
