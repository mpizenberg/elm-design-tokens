module Generate.NamingTest exposing (suite)

import Expect
import Generate.Naming as Naming
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Generate.Naming"
        [ describe "pathToIdentifier"
            [ test "single segment" <|
                \_ ->
                    Naming.pathToIdentifier [ "color" ]
                        |> Expect.equal "color"
            , test "two segments" <|
                \_ ->
                    Naming.pathToIdentifier [ "colors", "primary" ]
                        |> Expect.equal "colorsPrimary"
            , test "three segments" <|
                \_ ->
                    Naming.pathToIdentifier [ "spacing", "small", "x" ]
                        |> Expect.equal "spacingSmallX"
            , test "already capitalized segments" <|
                \_ ->
                    Naming.pathToIdentifier [ "Brand", "Primary" ]
                        |> Expect.equal "brandPrimary"
            , test "empty path" <|
                \_ ->
                    Naming.pathToIdentifier []
                        |> Expect.equal ""
            ]
        ]
