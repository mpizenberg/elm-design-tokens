module DesignTokens.FontWeightTest exposing (suite)

import DesignTokens.FontWeight as FontWeight exposing (FontWeight(..))
import DesignTokens.Fuzzers as Fuzzers
import Expect
import Json.Decode as Decode
import Json.Encode as Encode
import Test exposing (Test, describe, fuzz, test)


suite : Test
suite =
    describe "DesignTokens.FontWeight"
        [ decoderTests
        , encoderTests
        , roundTripTests
        , cssTests
        , toIntTests
        ]


decoderTests : Test
decoderTests =
    describe "decoder"
        [ test "decodes numeric" <|
            \_ ->
                "400"
                    |> Decode.decodeString FontWeight.decoder
                    |> Expect.equal (Ok (Numeric 400))
        , test "decodes bold string" <|
            \_ ->
                "\"bold\""
                    |> Decode.decodeString FontWeight.decoder
                    |> Expect.equal (Ok Bold)
        , test "decodes hairline alias" <|
            \_ ->
                "\"hairline\""
                    |> Decode.decodeString FontWeight.decoder
                    |> Expect.equal (Ok Thin)
        , test "decodes regular alias" <|
            \_ ->
                "\"regular\""
                    |> Decode.decodeString FontWeight.decoder
                    |> Expect.equal (Ok Normal)
        , test "decodes heavy alias" <|
            \_ ->
                "\"heavy\""
                    |> Decode.decodeString FontWeight.decoder
                    |> Expect.equal (Ok Black)
        , test "decodes ultra-light alias" <|
            \_ ->
                "\"ultra-light\""
                    |> Decode.decodeString FontWeight.decoder
                    |> Expect.equal (Ok ExtraLight)
        , test "decodes demi-bold alias" <|
            \_ ->
                "\"demi-bold\""
                    |> Decode.decodeString FontWeight.decoder
                    |> Expect.equal (Ok SemiBold)
        , test "fails on out of range" <|
            \_ ->
                "0"
                    |> Decode.decodeString FontWeight.decoder
                    |> Expect.err
        , test "fails on too high" <|
            \_ ->
                "1001"
                    |> Decode.decodeString FontWeight.decoder
                    |> Expect.err
        , test "fails on unknown string" <|
            \_ ->
                "\"super-bold\""
                    |> Decode.decodeString FontWeight.decoder
                    |> Expect.err
        ]


encoderTests : Test
encoderTests =
    describe "encode"
        [ test "encodes Numeric" <|
            \_ ->
                Numeric 450
                    |> FontWeight.encode
                    |> Encode.encode 0
                    |> Expect.equal "450"
        , test "encodes Bold as string" <|
            \_ ->
                Bold
                    |> FontWeight.encode
                    |> Encode.encode 0
                    |> Expect.equal "\"bold\""
        , test "encodes ExtraBlack" <|
            \_ ->
                ExtraBlack
                    |> FontWeight.encode
                    |> Encode.encode 0
                    |> Expect.equal "\"extra-black\""
        ]


roundTripTests : Test
roundTripTests =
    describe "round-trip"
        [ fuzz Fuzzers.fontWeight "encode >> decode is identity" <|
            \fw ->
                fw
                    |> FontWeight.encode
                    |> Decode.decodeValue FontWeight.decoder
                    |> Expect.equal (Ok fw)
        ]


cssTests : Test
cssTests =
    describe "toCssString"
        [ test "Bold is 700" <|
            \_ -> FontWeight.toCssString Bold |> Expect.equal "700"
        , test "Numeric passes through" <|
            \_ -> FontWeight.toCssString (Numeric 450) |> Expect.equal "450"
        , test "ExtraBlack is 950" <|
            \_ -> FontWeight.toCssString ExtraBlack |> Expect.equal "950"
        ]


toIntTests : Test
toIntTests =
    describe "toInt"
        [ test "Thin is 100" <| \_ -> FontWeight.toInt Thin |> Expect.equal 100
        , test "Normal is 400" <| \_ -> FontWeight.toInt Normal |> Expect.equal 400
        , test "Bold is 700" <| \_ -> FontWeight.toInt Bold |> Expect.equal 700
        ]
