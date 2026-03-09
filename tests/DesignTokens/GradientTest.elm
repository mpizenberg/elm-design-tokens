module DesignTokens.GradientTest exposing (suite)

import DesignTokens.Color as Color
import DesignTokens.Fuzzers as Fuzzers
import DesignTokens.Gradient as Gradient exposing (Gradient)
import Expect
import Json.Decode as Decode
import Test exposing (Test, describe, fuzz, test)


suite : Test
suite =
    describe "DesignTokens.Gradient"
        [ decoderTests
        , roundTripTests
        , cssTests
        ]


sampleGradient : Gradient
sampleGradient =
    [ { color = Color.srgb 1 0 0, position = 0 }
    , { color = Color.srgb 0 0 1, position = 1 }
    ]


decoderTests : Test
decoderTests =
    describe "decoder"
        [ test "decodes gradient stops" <|
            \_ ->
                """[{"color":{"colorSpace":"srgb","components":[1,0,0]},"position":0},{"color":{"colorSpace":"srgb","components":[0,0,1]},"position":1}]"""
                    |> Decode.decodeString Gradient.decoder
                    |> Expect.equal (Ok sampleGradient)
        , test "decodes empty gradient" <|
            \_ ->
                "[]"
                    |> Decode.decodeString Gradient.decoder
                    |> Expect.equal (Ok [])
        ]


roundTripTests : Test
roundTripTests =
    describe "round-trip"
        [ test "sample round-trips" <|
            \_ ->
                sampleGradient
                    |> Gradient.encode
                    |> Decode.decodeValue Gradient.decoder
                    |> Expect.equal (Ok sampleGradient)
        , fuzz Fuzzers.gradient "fuzz round-trip" <|
            \g ->
                g
                    |> Gradient.encode
                    |> Decode.decodeValue Gradient.decoder
                    |> Expect.equal (Ok g)
        ]


cssTests : Test
cssTests =
    describe "toCssString"
        [ test "two stops" <|
            \_ ->
                Gradient.toCssString sampleGradient
                    |> Expect.equal "color(srgb 1 0 0) 0%, color(srgb 0 0 1) 100%"
        , test "empty gradient" <|
            \_ ->
                Gradient.toCssString []
                    |> Expect.equal ""
        ]
