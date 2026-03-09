module DesignTokens.StrokeStyleTest exposing (suite)

import DesignTokens.Dimension as Dimension
import DesignTokens.StrokeStyle as StrokeStyle exposing (LineCap(..), StrokeStyle(..))
import Expect
import Json.Decode as Decode
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "DesignTokens.StrokeStyle"
        [ decoderTests
        , roundTripTests
        , cssTests
        ]


decoderTests : Test
decoderTests =
    describe "decoder"
        [ test "decodes string style" <|
            \_ ->
                "\"dashed\""
                    |> Decode.decodeString StrokeStyle.decoder
                    |> Expect.equal (Ok (StringStyle "dashed"))
        , test "decodes detailed style" <|
            \_ ->
                """{"dashArray":[{"value":3,"unit":"px"},{"value":6,"unit":"px"}],"lineCap":"round"}"""
                    |> Decode.decodeString StrokeStyle.decoder
                    |> Expect.equal
                        (Ok
                            (DetailedStyle
                                { dashArray = [ Dimension.px 3, Dimension.px 6 ]
                                , lineCap = Round
                                }
                            )
                        )
        , test "fails on unknown lineCap" <|
            \_ ->
                """{"dashArray":[],"lineCap":"unknown"}"""
                    |> Decode.decodeString StrokeStyle.decoder
                    |> Expect.err
        ]


roundTripTests : Test
roundTripTests =
    describe "round-trip"
        [ test "string style round-trips" <|
            \_ ->
                StringStyle "solid"
                    |> StrokeStyle.encode
                    |> Decode.decodeValue StrokeStyle.decoder
                    |> Expect.equal (Ok (StringStyle "solid"))
        , test "detailed style round-trips" <|
            \_ ->
                let
                    detailed : StrokeStyle
                    detailed =
                        DetailedStyle
                            { dashArray = [ Dimension.px 3, Dimension.px 6 ]
                            , lineCap = Butt
                            }
                in
                detailed
                    |> StrokeStyle.encode
                    |> Decode.decodeValue StrokeStyle.decoder
                    |> Expect.equal (Ok detailed)
        ]


cssTests : Test
cssTests =
    describe "toCssString"
        [ test "string style" <|
            \_ ->
                StrokeStyle.toCssString (StringStyle "dashed")
                    |> Expect.equal "dashed"
        , test "detailed style" <|
            \_ ->
                StrokeStyle.toCssString
                    (DetailedStyle
                        { dashArray = [ Dimension.px 3, Dimension.px 6 ]
                        , lineCap = Round
                        }
                    )
                    |> Expect.equal "3px 6px round"
        ]
