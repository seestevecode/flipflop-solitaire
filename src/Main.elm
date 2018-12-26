module Main exposing (main)

import Browser
import Dict exposing (Dict)
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Html exposing (Html)
import List.Extra as ListX


main =
    Browser.sandbox { init = init, update = update, view = view }


init : Model
init =
    let
        gameType =
            { name = "4-suit"
            , numFoundations = 4
            , numSuits = 4
            , numTableauCards = 25
            , tableauColSizes = [ 5, 5, 5, 5, 5 ]
            }
    in
    { gameType = gameType
    , board = boardFromDeck gameType <| deck gameType
    }


type alias Model =
    { gameType : GameType
    , board : Board
    }


type alias GameType =
    { name : String
    , numFoundations : Int
    , numSuits : Int
    , numTableauCards : Int
    , tableauColSizes : List Int
    }


type alias Board =
    { foundations : List (List Card)
    , tableau : Tableau
    , spare : ( Maybe Card, Maybe Card )
    , stock : List (List Card)
    }


type alias Card =
    { rank : Rank, suit : Suit, faceUp : Bool, id : Int }


type Rank
    = Ace
    | Two
    | Three
    | Four
    | Five
    | Six
    | Seven
    | Eight
    | Nine
    | Ten
    | Jack
    | Queen
    | King


type Suit
    = Spades
    | Hearts
    | Clubs
    | Diamonds
    | Stars


type alias Tableau =
    Dict Int (List Card)


boardFromDeck : GameType -> List Card -> Board
boardFromDeck gameType cards =
    { foundations = List.repeat gameType.numFoundations []
    , tableau =
        cards
            |> List.take gameType.numTableauCards
            |> buildTableau gameType
    , spare =
        let
            spareCards =
                cards
                    |> List.drop gameType.numTableauCards
                    |> List.take 2
        in
        ( List.head spareCards, ListX.last spareCards )
    , stock = []
    }


buildTableau : GameType -> List Card -> Tableau
buildTableau gameType cards =
    let
        tableauIndices =
            List.range 0 4

        tableauColSizes =
            gameType.tableauColSizes

        tableauColumns =
            ListX.groupsOfVarying tableauColSizes cards
    in
    List.map2 Tuple.pair tableauIndices tableauColumns
        |> Dict.fromList


deck : GameType -> List Card
deck gameType =
    let
        ranks =
            List.repeat gameType.numFoundations orderedRanks |> List.concat

        suits =
            ListX.cycle
                gameType.numFoundations
                (List.take gameType.numSuits orderedSuits)
                |> List.repeat 13
                |> List.concat
                |> ListX.gatherEquals
                |> List.concatMap (\( c, cs ) -> c :: cs)

        allFaceDown =
            List.repeat (gameType.numFoundations * 13) True

        ids =
            List.range 1 (gameType.numFoundations * 13)
    in
    List.map4 Card ranks suits allFaceDown ids


orderedRanks : List Rank
orderedRanks =
    [ Ace
    , Two
    , Three
    , Four
    , Five
    , Six
    , Seven
    , Eight
    , Nine
    , Ten
    , Jack
    , Queen
    , King
    ]


orderedSuits : List Suit
orderedSuits =
    [ Spades, Hearts, Clubs, Diamonds, Stars ]


update : Model -> msg -> Model
update model msg =
    model


scale : Float
scale =
    1


view : Model -> Html msg
view model =
    layout
        [ padding <| floor (10 * scale)
        , Background.color <| rgb255 157 120 85
        ]
    <|
        column [ spacing <| floor (10 * scale) ] <|
            List.map viewCard <|
                deck model.gameType


viewCard : Card -> Element msg
viewCard card =
    case card.faceUp of
        True ->
            viewCardFaceup card

        False ->
            viewCardFacedown card


viewCardFaceup : Card -> Element msg
viewCardFaceup card =
    column
        (globalCardAtts ++ [ Background.color <| rgb 1 1 1 ])
        [ viewCardFaceupHead card, viewCardFaceupBody card ]


viewCardFaceupHead : Card -> Element msg
viewCardFaceupHead card =
    row
        [ padding <| floor (3 * scale)
        , width fill
        , Font.size <| floor (20 * scale)
        , spacing <| floor (3 * scale)
        , Border.roundEach
            { topLeft = floor (4 * scale)
            , topRight = floor (4 * scale)
            , bottomLeft = 0
            , bottomRight = 0
            }
        , Background.color <| Tuple.second <| suitOutput card.suit
        , Font.color <| rgb 1 1 1
        ]
        [ viewRank card.rank
        , el [] <|
            text <|
                Tuple.first <|
                    suitOutput card.suit
        , el [ Font.size 10, alignRight ] <| text <| Debug.toString card.id
        ]


viewCardFaceupBody : Card -> Element msg
viewCardFaceupBody card =
    el
        [ Font.size <| floor (75 * scale)
        , centerX
        , Font.color <| Tuple.second <| suitOutput card.suit
        , paddingEach
            { bottom = floor (10 * scale)
            , left = 0
            , right = 0
            , top = 0
            }
        ]
    <|
        text <|
            Tuple.first <|
                suitOutput card.suit


viewCardFacedown : Card -> Element msg
viewCardFacedown card =
    let
        innerScale =
            1.05
    in
    el
        (globalCardAtts ++ [ Background.color <| rgb 1 1 1 ])
    <|
        el
            [ Border.rounded <| floor (4 * scale / innerScale)
            , width <| px <| floor (68 * scale / innerScale)
            , height <| px <| floor (105 * scale / innerScale)
            , Background.color <| rgb255 44 49 64
            , centerX
            , centerY
            ]
        <|
            none


viewCardSpace : Element msg
viewCardSpace =
    el (globalCardAtts ++ [ Background.color <| rgba 0 0 0 0.25 ]) <| none


globalCardAtts : List (Attribute msg)
globalCardAtts =
    [ Border.rounded <| floor (4 * scale)
    , width <| px <| floor (68 * scale)
    , height <| px <| floor (105 * scale)
    ]


viewRank : Rank -> Element msg
viewRank rank =
    el [] <|
        text <|
            case rank of
                Ace ->
                    "A"

                Two ->
                    "2"

                Three ->
                    "3"

                Four ->
                    "4"

                Five ->
                    "5"

                Six ->
                    "6"

                Seven ->
                    "7"

                Eight ->
                    "8"

                Nine ->
                    "9"

                Ten ->
                    "10"

                Jack ->
                    "J"

                Queen ->
                    "Q"

                King ->
                    "K"


suitOutput : Suit -> ( String, Color )
suitOutput suit =
    case suit of
        Hearts ->
            ( "♥", rgb255 218 87 53 )

        Clubs ->
            ( "♣", rgb255 54 55 36 )

        Diamonds ->
            ( "♦", rgb255 242 168 31 )

        Spades ->
            ( "♠", rgb255 114 147 181 )

        Stars ->
            ( "★", rgb255 109 167 128 )
