module Views.ParameterFormView exposing (editView, newView)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onCheck, onInput, onSubmit)
import Dict exposing (..)
import Models.Resources.Instance exposing (..)
import Models.Resources.ServiceStatus exposing (..)
import Models.Resources.JobStatus exposing (..)
import Models.Resources.Template exposing (..)
import Models.Ui.InstanceParameterForm as InstanceParameterForm exposing (InstanceParameterForm)
import Set exposing (Set)
import Maybe
import Date
import Updates.Messages exposing (UpdateBodyViewMsg(..))
import Utils.HtmlUtils exposing (icon, iconButtonText, iconButton)
import Utils.MaybeUtils as MaybeUtils

editingParamColor = "rgba(255, 177, 0, 0.46)"
normalParamColor = "#eee"

editView instance templates maybeInstanceParameterForm visibleSecrets =
  let
    ( otherParameters
    , otherParameterValues
    , otherParameterInfos
    , formIsBeingEdited
    ) =
    ( List.filter (\p -> p /= "id") instance.template.parameters
    , Dict.remove "id" instance.parameterValues
    , Dict.remove "id" instance.template.parameterInfos
    , MaybeUtils.isDefined maybeInstanceParameterForm
    )
  in
    let (otherParametersLeft, otherParametersRight) =
      let firstHalf =
        otherParameters
          |> List.length
          |> toFloat
          |> (\l -> l / 2)
          |> ceiling
      in
        ( List.take firstHalf otherParameters
        , List.drop firstHalf otherParameters
        )
    in
      Html.form
        [ onSubmit (ApplyParameterValueChanges instance) ]
        [ h5 [] [ text "Template" ]
        , templateSelectionView instance.template templates
        , h5 [] [ text "Parameters" ]
        , div
          [ class "row" ]
          [ div
            [ class "col-md-6" ]
            [ ( editParameterValueView instance instance.parameterValues instance.template.parameterInfos maybeInstanceParameterForm False visibleSecrets "id" ) ]
          ]
        , div
          [ class "row" ]
          [ div
            [ class "col-md-6" ]
            ( editParameterValuesView instance otherParametersLeft otherParameterValues otherParameterInfos maybeInstanceParameterForm visibleSecrets )
          , div
            [ class "col-md-6" ]
            ( editParameterValuesView instance otherParametersRight otherParameterValues otherParameterInfos maybeInstanceParameterForm visibleSecrets )
          ]
        , div
          [ class "row"
          , style [ ("margin-bottom", "15px") ]
          ]
          [ div
            [ class "col-md-6" ]
            [ iconButtonText
                ( if (formIsBeingEdited) then "btn btn-success" else "btn btn-default" )
                "fa fa-check"
                "Apply"
                [ disabled (not formIsBeingEdited)
                , type_ "submit"
                ]
            , text " "
            , iconButtonText
                ( if (formIsBeingEdited) then "btn btn-warning" else "btn btn-default" )
                "fa fa-ban"
                "Discard"
                [ disabled (not formIsBeingEdited)
                , onClick (DiscardParameterValueChanges instance)
                ]
            ]
          ]
        ]

templateSelectionView currentTemplate templates =
  let templatesWithoutCurrentTemplate =
    List.filter (\t -> t /= currentTemplate) templates
  in
    select
      [ class "form-control" ]
      ( List.append
        [ templateOption currentTemplate currentTemplate ]
        ( List.map (templateOption currentTemplate) templatesWithoutCurrentTemplate )
      )

templateOption currentTemplate template =
  let templateOption =
    if (currentTemplate == template) then
      "Unchanged"
    else if (currentTemplate.id == template.id) then
      "Upgrade to"
    else
      "Migrate to"
  in
    option []
      [ text templateOption
      , text ": "
      , text template.id
      , text " ("
      , text template.version
      , text ")"
      ]

editParameterValuesView instance parameters parameterValues parameterInfos maybeInstanceParameterForm visibleSecrets =
  List.map
    ( editParameterValueView instance parameterValues parameterInfos maybeInstanceParameterForm True visibleSecrets )
    parameters


editParameterValueView : Instance -> Dict String String -> Dict String ParameterInfo -> Maybe InstanceParameterForm -> Bool -> Set (InstanceId, String) -> String -> Html UpdateBodyViewMsg
editParameterValueView instance parameterValues parameterInfos maybeInstanceParameterForm enabled visibleSecrets parameter =
  let
    ( maybeParameterValue
    , maybeParameterInfo
    , maybeEditedValue
    ) =
    ( Dict.get parameter parameterValues
    , Dict.get parameter parameterInfos
    , MaybeUtils.concatMap (\f -> (Dict.get parameter f.changedParameterValues)) maybeInstanceParameterForm
    )
  in
    let
      ( placeholderValue
      , parameterValue
      , isSecret
      , secretVisible
      ) =
      ( maybeParameterInfo
          |> MaybeUtils.concatMap (\i -> i.default)
          |> Maybe.withDefault ""
      , maybeEditedValue
          |> Maybe.withDefault (Maybe.withDefault "" maybeParameterValue)
      , maybeParameterInfo
          |> MaybeUtils.concatMap (\i -> i.secret)
          |> Maybe.withDefault False
      , Set.member (instance.id, parameter) visibleSecrets
      )
    in
      p
        []
        [ div
          [ class "input-group" ]
          ( List.append
            [ span
              [ class "input-group-addon"
              , style
                [ ( "background-color", Maybe.withDefault normalParamColor (Maybe.map (\v -> editingParamColor) maybeEditedValue) )
                ]
              ]
              [ text parameter ]
            , input
              [ type_ ( if ( isSecret && ( not secretVisible ) ) then "password" else "text" )
              , class "form-control"
              , attribute "aria-label" parameter
              , placeholder placeholderValue
              , value parameterValue
              , disabled (not enabled)
              , onInput (EnterEditInstanceParameterValue instance parameter)
              ]
              []
            ]
            ( if (isSecret) then
                [ a
                  [ class "input-group-addon"
                  , attribute "role" "button"
                  , onClick ( ToggleEditInstanceSecretVisibility instance.id parameter )
                  ]
                  [ icon
                    ( String.concat
                      [ "glyphicon glyphicon-eye-"
                      , ( if secretVisible then "close" else "open" )
                      ]
                    )
                    []
                  ]
                , a
                  [ class "input-group-addon"
                  , attribute "role" "button"
                , attribute
                    "onclick"
                    ( String.concat
                      [ "copy('"
                      , parameterValue
                      , "')"
                      ]
                    )
                  ]
                  [ icon "glyphicon glyphicon-copy" [] ]
                ]
              else
                []
            )
          )
        ]

-- TODO visibleSecrets for the new instance form things need to be saved not only as Set (InstanceId, String) but also Set (TemplateId, String)
-- TODO parameterValues need to go away as we don't have any coming from the instance
-- TODO editParameterValueView needs to be adapted (probably copy paste for now?) so it can work without an instance as we don't have one here
newView template maybeInstanceParameterForm visibleSecrets =
  let
    ( otherParameters
    , otherParameterInfos
    , instanceParameterForms
    ) =
    ( List.filter (\p -> p /= "id") template.parameters
    , Dict.remove "id" template.parameterInfos
    , Maybe.withDefault InstanceParameterForm.empty maybeInstanceParameterForm
    )
  in
    let
      ( otherParametersLeft
      , otherParametersRight
      , formBeingEdited
      ) =
      let firstHalf =
        otherParameters
          |> List.length
          |> toFloat
          |> (\l -> l / 2)
          |> ceiling
      in
        ( List.take firstHalf otherParameters
        , List.drop firstHalf otherParameters
        , ( not (Dict.isEmpty instanceParameterForms.changedParameterValues) )
        )
    in
      Html.form
        [ onSubmit (SubmitNewInstanceCreation template.id instanceParameterForms.changedParameterValues) ]
        [ h5 [] [ text "Parameters" ]
        , div
          [ class "row" ]
          [ div
            [ class "col-md-6" ]
            [ ( newParameterValueView template template.parameterInfos maybeInstanceParameterForm False visibleSecrets "id" ) ]
          ]
        , div
          [ class "row" ]
          [ div
            [ class "col-md-6" ]
            ( newParameterValuesView template otherParametersLeft otherParameterInfos maybeInstanceParameterForm visibleSecrets )
          , div
            [ class "col-md-6" ]
            ( newParameterValuesView template otherParametersRight otherParameterInfos maybeInstanceParameterForm visibleSecrets )
          ]
        , div
          [ class "row"
          , style [ ("margin-bottom", "15px") ]
          ]
          [ div
            [ class "col-md-6" ]
            [ iconButtonText
                "btn btn-success"
                "fa fa-check"
                "Apply"
                [ type_ "submit" ]
            , text " "
            , iconButtonText
                "btn btn-warning"
                "fa fa-ban"
                "Discard"
                [ onClick (DiscardNewInstanceCreation template.id) ]
            ]
          ]
        ]

newParameterValuesView template parameters parameterInfos maybeInstanceParameterForm visibleSecrets =
  List.map
    ( newParameterValueView template parameterInfos maybeInstanceParameterForm True visibleSecrets )
    parameters


newParameterValueView : Template -> Dict String ParameterInfo -> Maybe InstanceParameterForm -> Bool -> Set (InstanceId, String) -> String -> Html UpdateBodyViewMsg
newParameterValueView template parameterInfos maybeInstanceParameterForm enabled visibleSecrets parameter =
  let
    ( maybeParameterInfo
    , maybeEditedValue
    ) =
    ( Dict.get parameter parameterInfos
    , MaybeUtils.concatMap (\f -> (Dict.get parameter f.changedParameterValues)) maybeInstanceParameterForm
    )
  in
    let
      ( placeholderValue
      , parameterValue
      , isSecret
      , secretVisible
      ) =
      ( maybeParameterInfo
          |> MaybeUtils.concatMap (\i -> i.default)
          |> Maybe.withDefault ""
      , maybeEditedValue
          |> Maybe.withDefault ""
      , maybeParameterInfo
          |> MaybeUtils.concatMap (\i -> i.secret)
          |> Maybe.withDefault False
      , Set.member (template.id, parameter) visibleSecrets
      )
    in
      p
        []
        [ div
          [ class "input-group" ]
          ( List.append
            [ span
              [ class "input-group-addon"
              , style
                [ ( "background-color", Maybe.withDefault normalParamColor (Maybe.map (\v -> editingParamColor) maybeEditedValue) )
                ]
              ]
              [ text parameter ]
            , input
              [ type_ ( if ( isSecret && ( not secretVisible ) ) then "password" else "text" )
              , class "form-control"
              , attribute "aria-label" parameter
              , placeholder placeholderValue
              , value parameterValue
              , disabled (not enabled)
              , onInput (EnterNewInstanceParameterValue template parameter)
              ]
              []
            ]
            ( if (isSecret) then
                [ a
                  [ class "input-group-addon"
                  , attribute "role" "button"
                  , onClick ( ToggleNewInstanceSecretVisibility template.id parameter )
                  ]
                  [ icon
                    ( String.concat
                      [ "glyphicon glyphicon-eye-"
                      , ( if secretVisible then "close" else "open" )
                      ]
                    )
                    []
                  ]
                , a
                  [ class "input-group-addon"
                  , attribute "role" "button"
                , attribute
                    "onclick"
                    ( String.concat
                      [ "copy('"
                      , parameterValue
                      , "')"
                      ]
                    )
                  ]
                  [ icon "glyphicon glyphicon-copy" [] ]
                ]
              else
                []
            )
          )
        ]
