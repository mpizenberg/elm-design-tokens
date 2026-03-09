module Generate.ThemeTest exposing (suite)

import DesignTokens.Color as Color
import DesignTokens.Dimension as Dimension
import DesignTokens.Token exposing (ResolvedToken, TokenValue(..))
import Expect
import Generate
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Generate.generateThemeModule"
        [ test "generates Theme type alias with varying fields" <|
            \_ ->
                Generate.generateThemeModule "Tokens"
                    [ ( "light", [ colorToken [ "bg" ] (colorVal 1 1 1) ] )
                    , ( "dark", [ colorToken [ "bg" ] (colorVal 0 0 0) ] )
                    ]
                    |> Result.map (String.contains "type alias Theme")
                    |> Expect.equal (Ok True)
        , test "base variant is full record literal" <|
            \_ ->
                Generate.generateThemeModule "Tokens"
                    [ ( "light", [ colorToken [ "bg" ] (colorVal 1 1 1) ] )
                    , ( "dark", [ colorToken [ "bg" ] (colorVal 0 0 0) ] )
                    ]
                    |> Result.map (String.contains "light : Theme")
                    |> Expect.equal (Ok True)
        , test "identical tokens become top-level constants" <|
            \_ ->
                Generate.generateThemeModule "Tokens"
                    [ ( "light"
                      , [ colorToken [ "bg" ] (colorVal 1 1 1)
                        , dimToken [ "spacing" ] (dimVal 8)
                        ]
                      )
                    , ( "dark"
                      , [ colorToken [ "bg" ] (colorVal 0 0 0)
                        , dimToken [ "spacing" ] (dimVal 8)
                        ]
                      )
                    ]
                    |> Result.map (\s -> String.contains "spacing : Dimension" s && not (String.contains "spacing" (extractThemeFields s)))
                    |> Expect.equal (Ok True)
        , test "record update for variant with partial diffs" <|
            \_ ->
                -- 3 fields all vary between variants, but dark only changes bg
                -- so dark uses record update
                Generate.generateThemeModule "Tokens"
                    [ ( "light"
                      , [ colorToken [ "bg" ] (colorVal 1 1 1)
                        , colorToken [ "fg" ] (colorVal 0 0 0)
                        , colorToken [ "accent" ] (colorVal 0.5 0.5 0.5)
                        ]
                      )
                    , ( "dark"
                      , [ colorToken [ "bg" ] (colorVal 0 0 0)
                        , colorToken [ "fg" ] (colorVal 0 0 0)
                        , colorToken [ "accent" ] (colorVal 0.5 0.5 0.5)
                        ]
                      )
                    , ( "highContrast"
                      , [ colorToken [ "bg" ] (colorVal 0 0 0)
                        , colorToken [ "fg" ] (colorVal 1 1 1)
                        , colorToken [ "accent" ] (colorVal 1 0 0)
                        ]
                      )
                    ]
                    |> Result.map (String.contains "{ light")
                    |> Expect.equal (Ok True)
        , test "all fields differ uses full record literal" <|
            \_ ->
                Generate.generateThemeModule "Tokens"
                    [ ( "light"
                      , [ colorToken [ "bg" ] (colorVal 1 1 1)
                        , colorToken [ "fg" ] (colorVal 0 0 0)
                        ]
                      )
                    , ( "dark"
                      , [ colorToken [ "bg" ] (colorVal 0 0 0)
                        , colorToken [ "fg" ] (colorVal 1 1 1)
                        ]
                      )
                    ]
                    |> Result.map (\s -> String.contains "dark : Theme" s && not (String.contains "{ light" s))
                    |> Expect.equal (Ok True)
        , test "identical values across variants become constants not Theme" <|
            \_ ->
                Generate.generateThemeModule "Tokens"
                    [ ( "light", [ colorToken [ "bg" ] (colorVal 1 1 1) ] )
                    , ( "copy", [ colorToken [ "bg" ] (colorVal 1 1 1) ] )
                    ]
                    |> Result.map (\s -> not (String.contains "Theme" s) && String.contains "bg : Color" s)
                    |> Expect.equal (Ok True)
        , test "mismatched paths returns error" <|
            \_ ->
                Generate.generateThemeModule "Tokens"
                    [ ( "light", [ colorToken [ "bg" ] (colorVal 1 1 1) ] )
                    , ( "dark", [ colorToken [ "fg" ] (colorVal 0 0 0) ] )
                    ]
                    |> Expect.err
        , test "no variants returns error" <|
            \_ ->
                Generate.generateThemeModule "Tokens" []
                    |> Expect.err
        , test "exposes Theme type and variant names" <|
            \_ ->
                Generate.generateThemeModule "Tokens"
                    [ ( "light", [ colorToken [ "bg" ] (colorVal 1 1 1) ] )
                    , ( "dark", [ colorToken [ "bg" ] (colorVal 0 0 0) ] )
                    ]
                    |> Result.map
                        (\s ->
                            String.contains "Theme" s
                                && String.contains "light" s
                                && String.contains "dark" s
                        )
                    |> Expect.equal (Ok True)
        ]



-- HELPERS


colorVal : Float -> Float -> Float -> TokenValue
colorVal r g b =
    ColorValue (Color.srgb r g b)


dimVal : Float -> TokenValue
dimVal n =
    DimensionValue (Dimension.px n)


colorToken : List String -> TokenValue -> ResolvedToken
colorToken path value =
    { path = path
    , typeName = "color"
    , value = value
    , aliasOf = Nothing
    , meta = { description = Nothing, extensions = Nothing, deprecated = Nothing }
    }


dimToken : List String -> TokenValue -> ResolvedToken
dimToken path value =
    { path = path
    , typeName = "dimension"
    , value = value
    , aliasOf = Nothing
    , meta = { description = Nothing, extensions = Nothing, deprecated = Nothing }
    }


{-| Extract the Theme type alias fields section for testing.
-}
extractThemeFields : String -> String
extractThemeFields s =
    case String.split "type alias Theme" s of
        _ :: rest :: _ ->
            case String.split "\n\n" rest of
                fields :: _ ->
                    fields

                _ ->
                    ""

        _ ->
            ""
