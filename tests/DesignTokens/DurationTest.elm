module DesignTokens.DurationTest exposing (suite)

import DesignTokens.Duration as Duration exposing (Duration, DurationUnit(..), ms, s)
import DesignTokens.Fuzzers as Fuzzers
import Expect
import Fuzz
import Json.Decode as Decode
import Json.Encode as Encode
import Test exposing (Test, describe, fuzz, test)


suite : Test
suite =
    describe "DesignTokens.Duration"
        [ decoderTests
        , encoderTests
        , roundTripTests
        , cssTests
        ]


decoderTests : Test
decoderTests =
    describe "decoder"
        [ test "decodes ms" <|
            \_ ->
                """{ "value": 200, "unit": "ms" }"""
                    |> Decode.decodeString Duration.decoder
                    |> Expect.equal (Ok { value = 200, unit = Ms })
        , test "decodes s" <|
            \_ ->
                """{ "value": 0.5, "unit": "s" }"""
                    |> Decode.decodeString Duration.decoder
                    |> Expect.equal (Ok { value = 0.5, unit = S })
        , test "fails on unknown unit" <|
            \_ ->
                """{ "value": 10, "unit": "min" }"""
                    |> Decode.decodeString Duration.decoder
                    |> Expect.err
        ]


encoderTests : Test
encoderTests =
    describe "encode"
        [ test "encodes ms" <|
            \_ ->
                ms 200
                    |> Duration.encode
                    |> Encode.encode 0
                    |> Expect.equal """{"value":200,"unit":"ms"}"""
        , test "encodes s" <|
            \_ ->
                s 0.5
                    |> Duration.encode
                    |> Encode.encode 0
                    |> Expect.equal """{"value":0.5,"unit":"s"}"""
        ]


roundTripTests : Test
roundTripTests =
    describe "round-trip"
        [ fuzz Fuzzers.duration "encode >> decode is identity" <|
            \dur ->
                dur
                    |> Duration.encode
                    |> Decode.decodeValue Duration.decoder
                    |> Expect.equal (Ok dur)
        ]


cssTests : Test
cssTests =
    describe "toCssString"
        [ test "ms" <|
            \_ -> Duration.toCssString (ms 200) |> Expect.equal "200ms"
        , test "s" <|
            \_ -> Duration.toCssString (s 0.5) |> Expect.equal "0.5s"
        ]
