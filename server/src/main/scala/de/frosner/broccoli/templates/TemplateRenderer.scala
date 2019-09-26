package de.frosner.broccoli.templates

import com.hubspot.jinjava.interpret.{FatalTemplateErrorsException, RenderResult}
import com.hubspot.jinjava.interpret.TemplateError.ErrorType
import com.hubspot.jinjava.{Jinjava, JinjavaConfig}
import de.frosner.broccoli.models.Instance
import org.fusesource.scalate.TemplateEngine
import play.api.libs.json.{JsValue, Json}

import scala.collection.JavaConversions._

/**
  * Renders json representation of the passed instance
  * @param jinjavaConfig Jinjava configuration
  */
class TemplateRenderer(jinjavaConfig: JinjavaConfig) {
  val jinjava = new Jinjava(jinjavaConfig)
  val engine = new TemplateEngine()

  def renderForResult(instance: Instance): RenderResult = {
    val template = instance.template
    val parameterInfos = template.parameterInfos
    val parameterDefaults = parameterInfos
      .map {
        case (name, parameterInfo) => (name, parameterInfo.default)
      }
      .collect {
        case (name, Some(value)) => (name, value)
      }
    val parameterValues = (parameterDefaults ++ instance.parameterValues).map {
      case (name, value) => (name, value.asJsonString)
    }
    jinjava.renderForResult(template.template, parameterValues)
  }

  def renderJson(instance: Instance): JsValue = {
    val renderResult = renderForResult(instance)
    val fatalErrors = renderResult.getErrors.filter(error => error.getSeverity == ErrorType.FATAL)

    if (fatalErrors.nonEmpty) {
      throw new FatalTemplateErrorsException(instance.template.template, fatalErrors)
    }

    Json.parse(renderResult.getOutput)
  }

  /**
    * Validates the parameterName supplied in a dummy jinjava template
    * @param parameterName String
    * @return true if the parameterName could be rendered successfully false otherwise
    */
  def validateParameterName(parameterName: String): Boolean = {
    val template = s"""{"somekey": "{{$parameterName}}"}"""
    !jinjava.renderForResult(template, Map(parameterName -> "testvalue")).hasErrors
  }
}
