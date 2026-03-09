module DesignTokens.FontFamilyTest exposing (suite)

import DesignTokens.FontFamily as FontFamily
import DesignTokens.Fuzzers as Fuzzers
import Expect
import Json.Decode as Decode
import Json.Encode as Encode
import Test exposing (Test, describe, fuzz, test)


suite : Test
suite =
    describe "DesignTokens.FontFamily"
        [ decoderTests
        , encoderTests
        , roundTripTests
        , cssTests
        , toListTests
        ]


decoderTests : Test
decoderTests =
    describe "decoder"
        [ test "decodes single string" <|
            \_ ->
                "\"Helvetica\""
                    |> Decode.decodeString FontFamily.decoder
                    |> Result.map FontFamily.toList
                    |> Expect.equal (Ok [ "Helvetica" ])
        , test "decodes array" <|
            \_ ->
                """["Helvetica", "Arial", "sans-serif"]"""
                    |> Decode.decodeString FontFamily.decoder
                    |> Result.map FontFamily.toList
                    |> Expect.equal (Ok [ "Helvetica", "Arial", "sans-serif" ])
        , test "fails on empty array" <|
            \_ ->
                "[]"
                    |> Decode.decodeString FontFamily.decoder
                    |> Expect.err
        ]


encoderTests : Test
encoderTests =
    describe "encode"
        [ test "single encodes as string" <|
            \_ ->
                FontFamily.single "Helvetica"
                    |> FontFamily.encode
                    |> Encode.encode 0
                    |> Expect.equal "\"Helvetica\""
        , test "stack encodes as array" <|
            \_ ->
                FontFamily.stack "Helvetica" [ "Arial" ]
                    |> FontFamily.encode
                    |> Encode.encode 0
                    |> Expect.equal "[\"Helvetica\",\"Arial\"]"
        ]


roundTripTests : Test
roundTripTests =
    describe "round-trip"
        [ fuzz Fuzzers.fontFamily "encode >> decode preserves toList" <|
            \ff ->
                ff
                    |> FontFamily.encode
                    |> Decode.decodeValue FontFamily.decoder
                    |> Result.map FontFamily.toList
                    |> Expect.equal (Ok (FontFamily.toList ff))
        ]


cssTests : Test
cssTests =
    describe "toCssString"
        [ test "single font" <|
            \_ ->
                FontFamily.single "Helvetica"
                    |> FontFamily.toCssString
                    |> Expect.equal "\"Helvetica\""
        , test "font stack" <|
            \_ ->
                FontFamily.stack "Helvetica Neue" [ "Arial", "sans-serif" ]
                    |> FontFamily.toCssString
                    |> Expect.equal "\"Helvetica Neue\", \"Arial\", \"sans-serif\""
        ]


toListTests : Test
toListTests =
    describe "toList"
        [ test "single" <|
            \_ ->
                FontFamily.single "Helvetica"
                    |> FontFamily.toList
                    |> Expect.equal [ "Helvetica" ]
        , test "stack" <|
            \_ ->
                FontFamily.stack "Helvetica" [ "Arial" ]
                    |> FontFamily.toList
                    |> Expect.equal [ "Helvetica", "Arial" ]
        ]
