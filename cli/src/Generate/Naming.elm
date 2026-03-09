module Generate.Naming exposing (pathToIdentifier)

{-| Convert token paths to valid Elm identifiers.
-}


{-| Convert a token path to a camelCase Elm identifier.

    pathToIdentifier [ "colors", "primary" ] == "colorsPrimary"

    pathToIdentifier [ "spacing", "small" ] == "spacingSmall"

-}
pathToIdentifier : List String -> String
pathToIdentifier path =
    case path of
        [] ->
            ""

        first :: rest ->
            String.toLower (String.left 1 first)
                ++ String.dropLeft 1 first
                ++ String.concat (List.map capitalize rest)


capitalize : String -> String
capitalize s =
    String.toUpper (String.left 1 s) ++ String.dropLeft 1 s
