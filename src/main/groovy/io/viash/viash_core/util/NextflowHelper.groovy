package io.viash.viash_core.util

/**
 * Helper to access Nextflow runtime state (Session, params, etc.)
 * from plugin code. Falls back gracefully when no session is available
 * (e.g. in unit tests).
 */
class NextflowHelper {

  /**
   * Get the current Nextflow session, or null if not available.
   */
  static nextflow.Session getSession() {
    def s = nextflow.Global.session
    return s != null ? s as nextflow.Session : null
  }

  /**
   * Whether the current run is a stub run.
   * Returns false when no session is available (e.g. in tests).
   */
  static boolean isStubRun() {
    def s = getSession()
    return s != null ? s.stubRun : false
  }

  /**
   * Get the current Nextflow params map.
   * Returns an empty map when no session is available.
   */
  static Map getParams() {
    def s = getSession()
    return s != null ? s.getParams() : [:]
  }

  /**
   * Get a single param value, or a default if not present.
   */
  static Object getParam(String key, Object defaultValue = null) {
    def p = getParams()
    return p.containsKey(key) ? p.get(key) : defaultValue
  }
}
