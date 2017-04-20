module Ws exposing (update)

import Json.Decode as Decode exposing (field)

import Models.Resources.AboutInfo as AboutInfo
import Models.Resources.Template as Template
import Models.Resources.Instance as Instance

import Updates.Messages exposing (UpdateAboutInfoMsg(..), UpdateLoginStatusMsg(..), UpdateErrorsMsg(..), UpdateTemplatesMsg(..))
import Messages exposing (AnyMsg(..))

import Array

import Utils.CmdUtils as CmdUtils
import Utils.StringUtils as StringUtils

payloadFieldName = "payload"

type WsMsgType
  = SetAboutInfoMsgType
  | ListTemplatesMsgType
  | ListInstancesMsgType
  | ErrorMsgType
  | UnknownMsgType String

-- TODO return also a Cmd
update msg model =
  let msgType =
    Decode.decodeString typeDecoder msg
  in
    case msgType of
      Ok SetAboutInfoMsgType ->
        let aboutInfoResult =
          Decode.decodeString (field payloadFieldName AboutInfo.decoder) msg
        in
          case aboutInfoResult of
            Ok aboutInfo ->
              ( { model | aboutInfo = Just aboutInfo }
              , Cmd.none
              )
            Err error ->
              ( { model | aboutInfo = Nothing }
              , showError "Failed to decode about info: " error
              )
      Ok ListTemplatesMsgType ->
        let templatesResult =
          Decode.decodeString (field payloadFieldName (Decode.array Template.decoder)) msg
        in
          case templatesResult of
            Ok templates ->
              ( { model | templates = (Array.toList templates) }
              , Cmd.none -- TODO send success message similar to error (enough to just send it for now)
              )
            Err error ->
              ( { model | templates = [] } -- TODO shall we just use the old templates instead?
              , showError "Failed to decode templates: " error
              )
      Ok ListInstancesMsgType ->
        let instancesResult =
          Decode.decodeString (field payloadFieldName (Decode.array Instance.decoder)) msg
        in
          case instancesResult of
            Ok instances ->
              ( { model | instances = (Array.toList instances) }
              , Cmd.none
              )
            Err error ->
              ( { model | instances = [] } -- TODO shall we just use the old templates instead?
              , showError "Failed to decode instances: " error
              )
      Ok ErrorMsgType ->
        let errorResult =
          Decode.decodeString (field payloadFieldName (Decode.string)) msg
        in
          case errorResult of
            Ok error ->
              ( model
              , showError "An error occured: " error
              )
            Err error ->
              ( model
              , showError "Failed to decode an error message: " error
              )
      Err error ->
        ( model
        , showError "Failed to decode web socket message: " error
        )
      Ok (UnknownMsgType unknown) ->
        ( model
        , showError "Unknown message type: " unknown
        )

typeDecoder =
  field "messageType" typeDecoderDecoder

typeDecoderDecoder =
  Decode.andThen
    (\typeString -> Decode.succeed (stringToType typeString))
    Decode.string

stringToType s =
  case s of
    "aboutInfo" -> SetAboutInfoMsgType
    "listTemplates" -> ListTemplatesMsgType
    "listInstances" -> ListInstancesMsgType
    "error" -> ErrorMsgType
    anything -> UnknownMsgType anything

showError prefix error =
  CmdUtils.cmd
    ( UpdateErrorsMsg
      ( AddError
        ( String.concat [prefix, error]
        )
      )
    )
