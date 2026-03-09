module Generate exposing (generateModule)

{-| Generate Elm module source code from resolved tokens.
-}

import DesignTokens.Token exposing (ResolvedToken)
import Elm.CodeGen as CG
import Elm.Pretty
import Generate.Expression as Expression
import Generate.Imports as Imports
import Generate.Naming as Naming


{-| Generate an Elm module from a module name and a list of resolved tokens.
Returns the formatted source code as a String.
-}
generateModule : String -> List ResolvedToken -> String
generateModule moduleName tokens =
    let
        modName : List String
        modName =
            String.split "." moduleName

        moduleDecl : CG.Module
        moduleDecl =
            CG.normalModule modName
                (List.map (\t -> CG.funExpose (Naming.pathToIdentifier t.path)) tokens)

        imports : List CG.Import
        imports =
            Imports.collectImports tokens

        declarations : List CG.Declaration
        declarations =
            List.map generateDeclaration tokens

        file : CG.File
        file =
            CG.file moduleDecl imports declarations Nothing
    in
    Elm.Pretty.pretty 100 file


generateDeclaration : ResolvedToken -> CG.Declaration
generateDeclaration token =
    let
        name : String
        name =
            Naming.pathToIdentifier token.path

        typeAnn : CG.TypeAnnotation
        typeAnn =
            tokenTypeAnnotation token.typeName

        expr : CG.Expression
        expr =
            case token.aliasOf of
                Just targetPath ->
                    CG.val (Naming.pathToIdentifier targetPath)

                Nothing ->
                    Expression.tokenValueToExpression token.value
    in
    CG.valDecl Nothing (Just typeAnn) name expr


tokenTypeAnnotation : String -> CG.TypeAnnotation
tokenTypeAnnotation typeName =
    case typeName of
        "color" ->
            CG.typed "Color" []

        "dimension" ->
            CG.typed "Dimension" []

        "fontFamily" ->
            CG.typed "FontFamily" []

        "fontWeight" ->
            CG.typed "FontWeight" []

        "duration" ->
            CG.typed "Duration" []

        "cubicBezier" ->
            CG.typed "CubicBezier" []

        "number" ->
            CG.floatAnn

        "string" ->
            CG.stringAnn

        "boolean" ->
            CG.boolAnn

        "shadow" ->
            CG.typed "Shadow" []

        "border" ->
            CG.typed "Border" []

        "strokeStyle" ->
            CG.typed "StrokeStyle" []

        "gradient" ->
            CG.typed "Gradient" []

        "typography" ->
            CG.typed "Typography" []

        "transition" ->
            CG.typed "Transition" []

        _ ->
            CG.stringAnn
