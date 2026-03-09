module DesignTokens.ColorTest exposing (suite)

import DesignTokens.Color as Color exposing (ColorSpace(..))
import DesignTokens.Fuzzers as Fuzzers
import Expect
import Json.Decode as Decode
import Test exposing (Test, describe, fuzz, test)


suite : Test
suite =
    describe "DesignTokens.Color"
        [ decoderTests
        , encoderTests
        , roundTripTests
        , cssTests
        , colorSpaceStringTests
        ]


decoderTests : Test
decoderTests =
    describe "decoder"
        [ test "decodes srgb color" <|
            \_ ->
                """{ "colorSpace": "srgb", "components": [0.2, 0.4, 0.8] }"""
                    |> Decode.decodeString Color.decoder
                    |> Expect.equal (Ok { colorSpace = Srgb, components = ( 0.2, 0.4, 0.8 ), alpha = 1 })
        , test "decodes with explicit alpha" <|
            \_ ->
                """{ "colorSpace": "oklch", "components": [0.65, 0.15, 250], "alpha": 0.5 }"""
                    |> Decode.decodeString Color.decoder
                    |> Expect.equal (Ok { colorSpace = Oklch, components = ( 0.65, 0.15, 250 ), alpha = 0.5 })
        , test "alpha defaults to 1" <|
            \_ ->
                """{ "colorSpace": "srgb", "components": [1, 0, 0] }"""
                    |> Decode.decodeString Color.decoder
                    |> Result.map .alpha
                    |> Expect.equal (Ok 1)
        , test "ignores hex field" <|
            \_ ->
                """{ "colorSpace": "srgb", "components": [1, 0, 0], "hex": "#ff0000" }"""
                    |> Decode.decodeString Color.decoder
                    |> Expect.ok
        , test "decodes display-p3" <|
            \_ ->
                """{ "colorSpace": "display-p3", "components": [1, 0, 0] }"""
                    |> Decode.decodeString Color.decoder
                    |> Result.map .colorSpace
                    |> Expect.equal (Ok DisplayP3)
        , test "fails on unknown color space" <|
            \_ ->
                """{ "colorSpace": "unknown", "components": [0, 0, 0] }"""
                    |> Decode.decodeString Color.decoder
                    |> Expect.err
        , test "fails on wrong component count" <|
            \_ ->
                """{ "colorSpace": "srgb", "components": [0, 0] }"""
                    |> Decode.decodeString Color.decoder
                    |> Expect.err
        ]


encoderTests : Test
encoderTests =
    describe "encode"
        [ test "encodes without alpha when 1" <|
            \_ ->
                Color.srgb 0.2 0.4 0.8
                    |> Color.encode
                    |> Decode.decodeValue (Decode.field "alpha" Decode.float)
                    |> Expect.err
        , test "encodes with alpha when not 1" <|
            \_ ->
                Color.srgb 0.2 0.4 0.8
                    |> Color.withAlpha 0.5
                    |> Color.encode
                    |> Decode.decodeValue (Decode.field "alpha" Decode.float)
                    |> Expect.equal (Ok 0.5)
        , test "encodes colorSpace as string" <|
            \_ ->
                Color.oklch 0.65 0.15 250
                    |> Color.encode
                    |> Decode.decodeValue (Decode.field "colorSpace" Decode.string)
                    |> Expect.equal (Ok "oklch")
        ]


roundTripTests : Test
roundTripTests =
    describe "round-trip"
        [ fuzz Fuzzers.color "encode >> decode is identity" <|
            \c ->
                c
                    |> Color.encode
                    |> Decode.decodeValue Color.decoder
                    |> Expect.equal (Ok c)
        ]


cssTests : Test
cssTests =
    describe "toCssString"
        [ test "srgb uses color()" <|
            \_ ->
                Color.srgb 0.2 0.4 0.8
                    |> Color.toCssString
                    |> Expect.equal "color(srgb 0.2 0.4 0.8)"
        , test "oklch uses dedicated function" <|
            \_ ->
                Color.oklch 0.65 0.15 250
                    |> Color.toCssString
                    |> Expect.equal "oklch(0.65 0.15 250)"
        , test "hsl uses dedicated function" <|
            \_ ->
                Color.hsl 180 0.5 0.5
                    |> Color.toCssString
                    |> Expect.equal "hsl(180 0.5 0.5)"
        , test "display-p3 uses color()" <|
            \_ ->
                Color.displayP3 1 0 0
                    |> Color.toCssString
                    |> Expect.equal "color(display-p3 1 0 0)"
        , test "alpha appended when not 1" <|
            \_ ->
                Color.srgb 1 0 0
                    |> Color.withAlpha 0.5
                    |> Color.toCssString
                    |> Expect.equal "color(srgb 1 0 0 / 0.5)"
        , test "alpha appended for dedicated function" <|
            \_ ->
                Color.oklch 0.65 0.15 250
                    |> Color.withAlpha 0.8
                    |> Color.toCssString
                    |> Expect.equal "oklch(0.65 0.15 250 / 0.8)"
        , test "srgb-linear uses color()" <|
            \_ ->
                Color.srgbLinear 0.5 0.5 0.5
                    |> Color.toCssString
                    |> Expect.equal "color(srgb-linear 0.5 0.5 0.5)"
        ]


colorSpaceStringTests : Test
colorSpaceStringTests =
    describe "colorSpaceToString / colorSpaceFromString"
        [ fuzz Fuzzers.colorSpace "round-trip" <|
            \cs ->
                cs
                    |> Color.colorSpaceToString
                    |> Color.colorSpaceFromString
                    |> Expect.equal (Just cs)
        , test "a98-rgb" <|
            \_ -> Color.colorSpaceFromString "a98-rgb" |> Expect.equal (Just A98Rgb)
        , test "prophoto-rgb" <|
            \_ -> Color.colorSpaceFromString "prophoto-rgb" |> Expect.equal (Just ProphotoRgb)
        , test "xyz-d65" <|
            \_ -> Color.colorSpaceFromString "xyz-d65" |> Expect.equal (Just XyzD65)
        ]
