module Main exposing (main)

import Board exposing (Board)
import Browser
import Card exposing (Card)
import Dict exposing (Dict)
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Element.Input as Input
import GameType exposing (GameType)
import Html exposing (Html)
import List.Extra as ListX
import Random
import Random.List


main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }


init : () -> ( Model, Cmd Msg )
init _ =
    ( initModel <| GameType.getGameType 0, Cmd.none )


type alias Model =
    { gameType : GameType
    , board : Board
    , selection : Selection
    , moves : Int
    , undoHistory : List Board
    , undoUsed : Bool
    , gameState : GameState
    }


type Selection
    = NoSelection
    | Spare Card
    | Tableau (List Card) Int


type GameState
    = NewGame
    | Playing
    | GameOver


type Msg
    = NewDeck (List Card)
    | Undo
    | Restart
    | StartGame GameType
    | SelectMsg SelectMsg
    | MoveMsg Board.MoveMsg


type SelectMsg
    = ClearSelection
    | SelectSpare Card
    | SelectTableau Card


initModel : GameType -> Model
initModel gameType =
    { gameType = gameType
    , board = GameType.boardFromDeck gameType <| GameType.deck gameType
    , selection = NoSelection
    , moves = 0
    , undoHistory = []
    , undoUsed = False
    , gameState = NewGame
    }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NewDeck cards ->
            ( { model | board = GameType.boardFromDeck model.gameType cards }
            , Cmd.none
            )

        Undo ->
            ( updateUndo model, Cmd.none )

        Restart ->
            ( updateRestart model, Cmd.none )

        StartGame newGameType ->
            ( initModel newGameType |> updateGameState
            , Random.generate NewDeck <|
                Random.List.shuffle <|
                    GameType.deck newGameType
            )

        SelectMsg subMsg ->
            ( { model | selection = updateSelect subMsg model }, Cmd.none )

        MoveMsg subMsg ->
            updateMove subMsg model


updateUndo : Model -> Model
updateUndo model =
    case model.undoHistory of
        [] ->
            model

        last :: rest ->
            { model
                | board = last
                , selection = NoSelection
                , undoHistory = rest
                , undoUsed = True
            }


updateRestart : Model -> Model
updateRestart model =
    case List.reverse model.undoHistory of
        [] ->
            model

        first :: _ ->
            { model
                | board = first
                , selection = NoSelection
                , undoHistory = []
                , undoUsed = True
            }


updateSelect : SelectMsg -> Model -> Selection
updateSelect msg model =
    case msg of
        ClearSelection ->
            NoSelection

        SelectTableau card ->
            let
                cards =
                    Board.selectFromCardInTableau card model.board.tableau
            in
            case Board.tableauColumn model.board.tableau card of
                Just col ->
                    if
                        Card.selectionValidTableauMove cards
                            || Card.selectionValidFoundationMove cards
                    then
                        Tableau cards col

                    else
                        model.selection

                Nothing ->
                    model.selection

        SelectSpare card ->
            if model.selection == Spare card then
                NoSelection

            else
                Spare card


updateMove : Board.MoveMsg -> Model -> ( Model, Cmd Msg )
updateMove msg model =
    case msg of
        Board.MoveTableauToTableau cards fromCol toCol ->
            ( updateModelTabToTab model cards fromCol toCol, Cmd.none )

        Board.MoveSpareToTableau card toCol ->
            if Board.validSprToTab model.board card toCol then
                ( { model | board = Board.moveSprToTab model.board card toCol }
                    |> updateModelAfterMove 1
                , Cmd.none
                )

            else
                ( model, Cmd.none )

        Board.MoveSpareToFoundation card toFnd ->
            if Board.validSprToFnd model.board card toFnd then
                ( { model | board = Board.moveSprToFnd model.board card toFnd }
                    |> updateModelAfterMove 1
                , Cmd.none
                )

            else
                ( model, Cmd.none )

        Board.MoveTableauToFoundation cards fromTab toFnd ->
            if Board.validTabToFnd model.board cards fromTab toFnd then
                ( { model
                    | board = Board.moveTabToFnd model.board cards fromTab toFnd
                  }
                    |> updateModelAfterMove (List.length cards)
                , Cmd.none
                )

            else
                ( model, Cmd.none )

        Board.MoveStockToTableau ->
            ( { model | board = Board.addCardsFromStock model.board }
                |> updateModelAfterMove 1
            , Cmd.none
            )


updateModelTabToTab : Model -> List Card -> Int -> Int -> Model
updateModelTabToTab model cards fromCol toCol =
    case Board.validTabToTab model.board cards fromCol toCol of
        ( True, Just False ) ->
            { model
                | board =
                    Board.moveTabToTab model.board cards fromCol toCol
            }
                |> updateModelAfterMove 1

        ( True, Just True ) ->
            { model
                | board =
                    Board.moveTabToTab model.board
                        (List.reverse cards)
                        fromCol
                        toCol
            }
                |> updateModelAfterMove (List.length cards)

        _ ->
            model


updateModelAfterMove : Int -> Model -> Model
updateModelAfterMove movesIncrement model =
    { model
        | selection = NoSelection
        , moves = model.moves + movesIncrement
        , undoHistory = model.board :: model.undoHistory
    }
        |> updateGameState


updateGameState : Model -> Model
updateGameState model =
    case model.gameState of
        NewGame ->
            { model | gameState = Playing }

        Playing ->
            { model
                | gameState =
                    if progress model == 100 then
                        GameOver

                    else
                        Playing
            }

        GameOver ->
            model


view : Model -> Html Msg
view model =
    layout
        [ padding 10, Background.color <| backgroundColour ]
    <|
        row [ centerX, spacing 25, height fill ]
            [ viewMain model, viewSidebar model ]


viewMain : Model -> Element Msg
viewMain model =
    column [ spacing 25, alignTop, width <| px <| Card.cardWidth * 6 ] <|
        case model.gameState of
            NewGame ->
                [ none ]

            Playing ->
                [ viewFoundations model, viewTableau model ]

            GameOver ->
                [ none ]


viewFoundations : Model -> Element Msg
viewFoundations model =
    let
        spacer =
            case model.gameType.numFoundations of
                4 ->
                    [ el Card.globalCardAtts none ]

                _ ->
                    [ none ]

        foundations =
            List.indexedMap (viewFoundation model.selection)
                model.board.foundations
    in
    row [ spacing 10, centerX ] <| foundations ++ spacer


viewFoundation : Selection -> Int -> List Card -> Element Msg
viewFoundation selection foundation cards =
    case List.reverse cards of
        [] ->
            Card.viewCardSpace <| foundationSelectionAtts selection foundation

        last :: _ ->
            viewCard selection last <|
                foundationSelectionAtts selection foundation


foundationSelectionAtts : Selection -> Int -> List (Attribute Msg)
foundationSelectionAtts selection foundation =
    case selection of
        Spare spareCard ->
            [ pointer
            , Events.onClick <|
                MoveMsg (Board.MoveSpareToFoundation spareCard foundation)
            ]

        Tableau tabCards tabCol ->
            [ pointer
            , Events.onClick <|
                MoveMsg
                    (Board.MoveTableauToFoundation tabCards tabCol foundation)
            ]

        _ ->
            []


viewCard : Selection -> Card -> List (Attribute Msg) -> Element Msg
viewCard selection card attr =
    case card.orientation of
        Card.FaceUp ->
            viewCardFaceup selection card attr

        Card.FaceDown ->
            Card.viewCardFacedown


viewCardFaceup : Selection -> Card -> List (Attribute Msg) -> Element Msg
viewCardFaceup selection card attr =
    column
        (Card.globalCardAtts ++ attr ++ [ Background.color <| rgb 1 1 1 ])
        [ viewCardFaceupHead selection card, Card.viewCardFaceupBody card ]


viewCardFaceupHead : Selection -> Card -> Element msg
viewCardFaceupHead selection card =
    row
        [ padding 3
        , width fill
        , Font.size 20
        , spacing 3
        , Border.roundEach
            { topLeft = Card.cardCornerRound
            , topRight = Card.cardCornerRound
            , bottomLeft = 0
            , bottomRight = 0
            }
        , Background.color <| Tuple.second <| Card.suitOutput card.suit
        , Font.color <| rgb 1 1 1
        ]
        [ Card.viewRank card.rank
        , el [] <| text <| Tuple.first <| Card.suitOutput card.suit
        , if cardSelected selection card then
            el [ alignRight, Font.color <| rgb 1 1 1 ] <| text "●"

          else
            none
        ]


cardSelected : Selection -> Card -> Bool
cardSelected selection card =
    case selection of
        Spare spareCard ->
            card == spareCard

        Tableau tabCards _ ->
            List.member card tabCards

        NoSelection ->
            False


viewSidebar : Model -> Element Msg
viewSidebar model =
    let
        sidebarHeader =
            el [ centerX, Font.size 22, Font.bold ] <| text "FlipFlop"

        sidebarBurger =
            Input.button [ centerX, Font.size 25 ]
                { onPress = Nothing, label = text "≡" }
    in
    column sidebarAtts <|
        case model.gameState of
            NewGame ->
                [ sidebarHeader
                , el [ centerX ] <| text "New Game"
                , sidebarBurger
                , viewSelectGame
                ]

            Playing ->
                [ sidebarHeader
                , viewInfo model
                , sidebarBurger
                , viewSpare model
                , viewStock <| List.length model.board.stock
                ]

            GameOver ->
                [ sidebarHeader
                , el [] <| text "Game Over"
                , sidebarBurger
                , viewSelectGame
                ]


sidebarAtts : List (Attribute Msg)
sidebarAtts =
    [ spacing 25
    , alignTop
    , width <| px <| floor <| toFloat Card.cardWidth * 2.5
    , height fill
    , padding 10
    , Background.color <| rgba 0 0 0 0.25
    , Font.size 15
    , Font.color sidebarFontColour
    ]


viewSelectGame : Element Msg
viewSelectGame =
    let
        newGameLink gameType =
            Input.button [ centerX ]
                { onPress = Just (StartGame <| GameType.getGameType gameType)
                , label = text <| .name <| GameType.getGameType gameType
                }
    in
    column [ spacing 20, centerX ] <|
        List.map newGameLink (Dict.keys GameType.validGameTypes)


viewInfo : Model -> Element Msg
viewInfo model =
    let
        movesText =
            if model.moves == 1 then
                "1 move"

            else
                String.fromInt model.moves ++ " moves"

        undoTextEl =
            if model.undoUsed then
                text "Undo used"

            else
                none
    in
    column
        [ Font.size 15
        , spacing 10
        , centerX
        , height <| px <| floor <| toFloat Card.cardHeight * 1.25
        ]
        [ el [ centerX, Font.size 18, Font.bold ] <|
            text <|
                model.gameType.name
        , el [ centerX ] <|
            text <|
                String.fromInt (progress model)
                    ++ "% completed"
        , el [ centerX ] <| text <| movesText
        , el [ centerX, height (fill |> minimum 20) ] <| undoTextEl
        ]


progress : Model -> Int
progress model =
    let
        numFoundationCards =
            model.board.foundations |> List.concat |> List.length |> toFloat

        numTargetCards =
            model.gameType.numFoundations * 13 |> toFloat
    in
    round <| numFoundationCards / numTargetCards * 100


viewUndoButton : Element Msg
viewUndoButton =
    Input.button [ alignLeft ] { onPress = Just Undo, label = text "Undo" }


viewRestartButton : Element Msg
viewRestartButton =
    Input.button [ alignRight ]
        { onPress = Just Restart, label = text "Restart" }


viewTableau : Model -> Element Msg
viewTableau model =
    row [ spacing 10, centerX ] <|
        List.map (viewTableauColumn model) (Dict.keys model.board.tableau)


viewTableauColumn : Model -> Int -> Element Msg
viewTableauColumn model colIndex =
    Board.getTableauColumn model.board.tableau colIndex
        |> viewColumn model.selection colIndex


viewColumn : Selection -> Int -> List Card -> Element Msg
viewColumn selection colIndex cards =
    column
        ([ alignTop, spacing -81 ]
            ++ columnSelectionAtts selection colIndex
            ++ Board.columnWarningAtts cards
        )
    <|
        case cards of
            [] ->
                List.singleton <| Card.viewCardSpace []

            cs ->
                List.map
                    (\c ->
                        viewCard selection
                            c
                            [ pointer
                            , Events.onClick <| SelectMsg (SelectTableau c)
                            ]
                    )
                    cs


columnSelectionAtts : Selection -> Int -> List (Attribute Msg)
columnSelectionAtts selection colIndex =
    case selection of
        Tableau tabCards tabCol ->
            [ pointer
            , if colIndex == tabCol then
                Events.onClick (SelectMsg ClearSelection)

              else
                Events.onClick <|
                    MoveMsg
                        (Board.MoveTableauToTableau tabCards tabCol colIndex)
            ]

        Spare spareCard ->
            [ pointer
            , Events.onClick <|
                MoveMsg (Board.MoveSpareToTableau spareCard colIndex)
            ]

        _ ->
            []


viewSpare : Model -> Element Msg
viewSpare model =
    let
        viewSingleSpare spare =
            case spare of
                Nothing ->
                    el Card.globalCardAtts none

                Just s ->
                    viewCard model.selection
                        s
                        [ Events.onClick <| SelectMsg (SelectSpare s), pointer ]

        selectAttr =
            [ Events.onClick SelectSpare, pointer ]
    in
    row [ spacing 10 ]
        [ viewSingleSpare <| Tuple.first model.board.spare
        , viewSingleSpare <| Tuple.second model.board.spare
        ]



-- Sidebar


viewStock : Int -> Element Msg
viewStock stockGroups =
    case stockGroups of
        0 ->
            none

        numGroups ->
            el [ pointer, Events.onClick <| MoveMsg Board.MoveStockToTableau ]
                Card.viewCardFacedown
                :: List.repeat (numGroups - 1) Card.viewCardFacedown
                |> List.reverse
                |> row [ alignLeft, spacing -50 ]



-- Subscriptions


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- Constants


backgroundColour : Color
backgroundColour =
    rgb255 157 120 85


sidebarFontColour : Color
sidebarFontColour =
    rgb 1 1 1
