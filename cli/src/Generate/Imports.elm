module Generate.Imports exposing (collectImports)

{-| Collect required imports from a list of resolved tokens.
-}

import DesignTokens.Token exposing (ResolvedToken)
import Elm.CodeGen as CG
import Set exposing (Set)


{-| Collect unique imports needed for a list of resolved tokens.
-}
collectImports : List ResolvedToken -> List CG.Import
collectImports tokens =
    tokens
        |> List.concatMap (.typeName >> importsForTypeName)
        |> Set.fromList
        |> Set.toList
        |> List.filterMap importForKey


{-| Return import key strings for a DTCG type name.
Composite types pull in their nested type imports too.
-}
importsForTypeName : String -> List String
importsForTypeName typeName =
    case typeName of
        "color" ->
            [ "Color" ]

        "dimension" ->
            [ "Dimension" ]

        "fontFamily" ->
            [ "FontFamily" ]

        "fontWeight" ->
            [ "FontWeight" ]

        "duration" ->
            [ "Duration" ]

        "cubicBezier" ->
            [ "CubicBezier" ]

        "shadow" ->
            [ "Shadow", "Color", "Dimension" ]

        "border" ->
            [ "Border", "Color", "Dimension" ]

        "strokeStyle" ->
            [ "StrokeStyle", "Dimension" ]

        "gradient" ->
            [ "Gradient", "Color" ]

        "typography" ->
            [ "Typography", "FontFamily", "Dimension", "FontWeight" ]

        "transition" ->
            [ "Transition", "Duration", "CubicBezier" ]

        _ ->
            []


{-| Create an import statement for a given import key.
-}
importForKey : String -> Maybe CG.Import
importForKey key =
    case key of
        "Color" ->
            Just <|
                CG.importStmt [ "DesignTokens", "Color" ]
                    (Just [ "Color" ])
                    (Just (CG.exposeExplicit [ CG.closedTypeExpose "Color" ]))

        "Dimension" ->
            Just <|
                CG.importStmt [ "DesignTokens", "Dimension" ]
                    (Just [ "Dimension" ])
                    (Just (CG.exposeExplicit [ CG.closedTypeExpose "Dimension" ]))

        "FontFamily" ->
            Just <|
                CG.importStmt [ "DesignTokens", "FontFamily" ]
                    (Just [ "FontFamily" ])
                    (Just (CG.exposeExplicit [ CG.closedTypeExpose "FontFamily" ]))

        "FontWeight" ->
            Just <|
                CG.importStmt [ "DesignTokens", "FontWeight" ]
                    (Just [ "FontWeight" ])
                    (Just (CG.exposeExplicit [ CG.openTypeExpose "FontWeight" ]))

        "Duration" ->
            Just <|
                CG.importStmt [ "DesignTokens", "Duration" ]
                    (Just [ "Duration" ])
                    (Just (CG.exposeExplicit [ CG.closedTypeExpose "Duration" ]))

        "CubicBezier" ->
            Just <|
                CG.importStmt [ "DesignTokens", "CubicBezier" ]
                    Nothing
                    (Just (CG.exposeExplicit [ CG.closedTypeExpose "CubicBezier" ]))

        "Shadow" ->
            Just <|
                CG.importStmt [ "DesignTokens", "Shadow" ]
                    Nothing
                    (Just (CG.exposeExplicit [ CG.closedTypeExpose "Shadow" ]))

        "Border" ->
            Just <|
                CG.importStmt [ "DesignTokens", "Border" ]
                    Nothing
                    (Just (CG.exposeExplicit [ CG.closedTypeExpose "Border" ]))

        "StrokeStyle" ->
            Just <|
                CG.importStmt [ "DesignTokens", "StrokeStyle" ]
                    (Just [ "StrokeStyle" ])
                    (Just (CG.exposeExplicit [ CG.openTypeExpose "StrokeStyle", CG.openTypeExpose "LineCap" ]))

        "Gradient" ->
            Just <|
                CG.importStmt [ "DesignTokens", "Gradient" ]
                    Nothing
                    (Just (CG.exposeExplicit [ CG.closedTypeExpose "Gradient", CG.closedTypeExpose "GradientStop" ]))

        "Typography" ->
            Just <|
                CG.importStmt [ "DesignTokens", "Typography" ]
                    Nothing
                    (Just (CG.exposeExplicit [ CG.closedTypeExpose "Typography" ]))

        "Transition" ->
            Just <|
                CG.importStmt [ "DesignTokens", "Transition" ]
                    (Just [ "Transition" ])
                    (Just (CG.exposeExplicit [ CG.closedTypeExpose "Transition", CG.openTypeExpose "TimingFunction" ]))

        _ ->
            Nothing
