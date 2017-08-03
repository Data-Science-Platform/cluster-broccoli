package de.frosner.broccoli.instances.conf

import com.typesafe.config.Config

/**
  * Configuration for CouchDBInstanceStorage
  *
  * @param url database address
  * @param dbName database name where the instance information will be stored
  */
final case class CouchDBInstanceStorageConfiguration(url: String, dbName: String)

object CouchDBInstanceStorageConfiguration {
  protected val log = play.api.Logger(getClass)

  def fromConfig(config: Config): CouchDBInstanceStorageConfiguration = {
    val url = config.getString("url")
    log.info(s"broccoli.instances.storage.couchdb.url=$url")
    val dbName = config.getString("dbName")
    log.info(s"broccoli.instances.storage.couchdb.dbName=$dbName")
    CouchDBInstanceStorageConfiguration(url, dbName)
  }

}
