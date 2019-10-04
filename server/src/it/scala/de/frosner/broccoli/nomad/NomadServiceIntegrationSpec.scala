package de.frosner.broccoli.nomad

import io.lemonlabs.uri.Url
import de.frosner.broccoli.services.NomadService
import de.frosner.broccoli.test.contexts.WSClientContext
import de.frosner.broccoli.test.contexts.docker.BroccoliDockerContext
import de.frosner.broccoli.test.contexts.docker.BroccoliTestService.{Broccoli, Nomad}
import org.specs2.concurrent.ExecutionEnv
import org.specs2.mutable.Specification
import play.api.libs.json.Json
import play.api.libs.ws.WSClient

import scala.util.Success

class NomadServiceIntegrationSpec(implicit ee: ExecutionEnv)
  extends Specification
    with WSClientContext
    with BroccoliDockerContext {

  /**
    * Start Broccoli and Nomad for our tests.  We need Broccoli to spawn instances, and Nomad to test the client.
    */
  override def broccoliDockerConfig: BroccoliDockerContext.Configuration =
    BroccoliDockerContext.Configuration.services(Broccoli, Nomad)

  "The NomadService" should {
    "parse HCL jobs for nomad version >= 0.9.1" >> { wsClient: WSClient =>
      val hclJob = "job \"example\" { type = \"service\" group \"cache\" {} }"
      val jsonJob = Json.parse(
        """{"Affinities":null,"AllAtOnce":false,"Constraints":null,"CreateIndex":0,"Datacenters":null,
          |"Dispatched":false,"ID":"example","JobModifyIndex":0,"Meta":null,"Migrate":null,"ModifyIndex":0,"Name":"example",
          |"Namespace":"default","ParameterizedJob":null,"ParentID":"","Payload":null,"Periodic":null,"Priority":50,
          |"Region":"global","Reschedule":null,"Spreads":null,"Stable":false,"Status":"","StatusDescription":"",
          |"Stop":false,"SubmitTime":null,"TaskGroups":[{"Affinities":null,"Constraints":null,"Count":1,
          |"EphemeralDisk":{"Migrate":false,"SizeMB":300,"Sticky":false},"Meta":null,"Migrate":{"HealthCheck":
          |"checks","HealthyDeadline":300000000000,"MaxParallel":1,"MinHealthyTime":10000000000},"Name":"cache",
          |"ReschedulePolicy":{"Attempts":0,"Delay":30000000000,"DelayFunction":"exponential","Interval":0,
          |"MaxDelay":3600000000000,"Unlimited":true},"RestartPolicy":{"Attempts":2,"Delay":15000000000,
          |"Interval":1800000000000,"Mode":"fail"},"Spreads":null,"Tasks":null,"Update":null}],"Type":"service",
          |"Update":null,"VaultToken":"","Version":0}""".stripMargin)
      val service = new NomadService(NomadConfiguration("http://localhost:4646", "NOMAD_BROCCOLI_TOKEN", false, ""), wsClient)
      val client = new NomadHttpClient(Url.parse("http://localhost:4646"), "NOMAD_BROCCOLI_TOKEN", wsClient)
      if(client.nomadVersion < "0.9.1") {
        val result = service.parseHCLJob(hclJob)
        if (result == Success(jsonJob)) {
          success
        } else {
          failure(s"Failed to match json. Got $result")
        }
      } else {
        skipped("Skipping as nomad version is older")
      }
    }
  }
}
