module DesignTokens.CubicBezierTest exposing (suite)

import DesignTokens.CubicBezier as CubicBezier exposing (CubicBezier)
import DesignTokens.Fuzzers as Fuzzers
import Expect
import Fuzz
import Json.Decode as Decode
import Json.Encode as Encode
import Test exposing (Test, describe, fuzz, test)


suite : Test
suite =
    describe "DesignTokens.CubicBezier"
        [ decoderTests
        , encoderTests
        , roundTripTests
        , cssTests
        ]


decoderTests : Test
decoderTests =
    describe "decoder"
        [ test "decodes valid bezier" <|
            \_ ->
                "[0.5, 0, 1, 1]"
                    |> Decode.decodeString CubicBezier.decoder
                    |> Expect.equal (Ok { p1x = 0.5, p1y = 0, p2x = 1, p2y = 1 })
        , test "allows negative p1y" <|
            \_ ->
                "[0.5, -0.5, 1, 1.5]"
                    |> Decode.decodeString CubicBezier.decoder
                    |> Expect.equal (Ok { p1x = 0.5, p1y = -0.5, p2x = 1, p2y = 1.5 })
        , test "fails when p1x > 1" <|
            \_ ->
                "[1.5, 0, 1, 1]"
                    |> Decode.decodeString CubicBezier.decoder
                    |> Expect.err
        , test "fails when p2x < 0" <|
            \_ ->
                "[0.5, 0, -0.1, 1]"
                    |> Decode.decodeString CubicBezier.decoder
                    |> Expect.err
        , test "fails on wrong array length" <|
            \_ ->
                "[0.5, 0, 1]"
                    |> Decode.decodeString CubicBezier.decoder
                    |> Expect.err
        ]


encoderTests : Test
encoderTests =
    describe "encode"
        [ test "encodes as array" <|
            \_ ->
                CubicBezier 0.5 0 1 1
                    |> CubicBezier.encode
                    |> Encode.encode 0
                    |> Expect.equal "[0.5,0,1,1]"
        ]


roundTripTests : Test
roundTripTests =
    describe "round-trip"
        [ fuzz Fuzzers.cubicBezier "encode >> decode is identity" <|
            \cb ->
                cb
                    |> CubicBezier.encode
                    |> Decode.decodeValue CubicBezier.decoder
                    |> Expect.equal (Ok cb)
        ]


cssTests : Test
cssTests =
    describe "toCssString"
        [ test "formats correctly" <|
            \_ ->
                CubicBezier.toCssString { p1x = 0.5, p1y = 0, p2x = 1, p2y = 1 }
                    |> Expect.equal "cubic-bezier(0.5, 0, 1, 1)"
        ]
