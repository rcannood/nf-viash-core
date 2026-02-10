package io.viash.viash_core.config

import io.viash.viash_core.util.NextflowHelper

/**
 * Directive validation and processing utilities for Nextflow process directives.
 */
class DirectiveUtils {

  /**
   * Validate and normalize Nextflow process directives.
   * Reads the container registry override from NF params automatically.
   *
   * @param drctv The directives map (will be cloned, not modified in place).
   * @param containerRegistryOverride Optional explicit override for container registry.
   *        If null, reads from params.override_container_registry.
   * @return The validated and normalized directives map.
   */
  static Map processDirectives(Map drctv, String containerRegistryOverride = null) {
    // If no explicit override, read from NF params
    if (containerRegistryOverride == null) {
      containerRegistryOverride = NextflowHelper.getParam("override_container_registry") as String
    }

    // remove null values
    drctv = drctv.findAll { k, v -> v != null }

    // check for unexpected keys
    def expectedKeys = [
      "accelerator", "afterScript", "beforeScript", "cache", "conda", "container", "containerOptions", "cpus", "disk", "echo", "errorStrategy", "executor", "machineType", "maxErrors", "maxForks", "maxRetries", "memory", "module", "penv", "pod", "publishDir", "queue", "label", "scratch", "storeDir", "stageInMode", "stageOutMode", "tag", "time"
    ]
    def unexpectedKeys = drctv.keySet() - expectedKeys
    assert unexpectedKeys.isEmpty() : "Unexpected keys in process directive: '${unexpectedKeys.join("', '")}'"

    if (drctv.containsKey("accelerator")) {
      ConfigUtils.assertMapKeys(drctv["accelerator"], ["type", "limit", "request", "runtime"], [], "accelerator")
    }

    if (drctv.containsKey("afterScript")) {
      assert drctv["afterScript"] instanceof CharSequence
    }

    if (drctv.containsKey("beforeScript")) {
      assert drctv["beforeScript"] instanceof CharSequence
    }

    if (drctv.containsKey("cache")) {
      assert drctv["cache"] instanceof CharSequence || drctv["cache"] instanceof Boolean
      if (drctv["cache"] instanceof CharSequence) {
        assert drctv["cache"] in ["deep", "lenient"] : "Unexpected value for cache"
      }
    }

    if (drctv.containsKey("conda")) {
      if (drctv["conda"] instanceof List) {
        drctv["conda"] = drctv["conda"].join(" ")
      }
      assert drctv["conda"] instanceof CharSequence
    }

    if (drctv.containsKey("container")) {
      assert drctv["container"] instanceof Map || drctv["container"] instanceof CharSequence
      if (drctv["container"] instanceof Map) {
        def m = drctv["container"]
        ConfigUtils.assertMapKeys(m, ["registry", "image", "tag"], ["image"], "container")
        def envOverride = System.getenv('OVERRIDE_CONTAINER_REGISTRY')
        def part1 =
          envOverride ? envOverride + "/" :
          containerRegistryOverride ? containerRegistryOverride + "/" :
          m.registry ? m.registry + "/" :
          ""
        def part2 = m.image
        def part3 = m.tag ? ":" + m.tag : ":latest"
        drctv["container"] = part1 + part2 + part3
      }
    }

    if (drctv.containsKey("containerOptions")) {
      if (drctv["containerOptions"] instanceof List) {
        drctv["containerOptions"] = drctv["containerOptions"].join(" ")
      }
      assert drctv["containerOptions"] instanceof CharSequence
    }

    if (drctv.containsKey("cpus")) {
      assert drctv["cpus"] instanceof Integer
    }

    if (drctv.containsKey("disk")) {
      assert drctv["disk"] instanceof CharSequence
    }

    if (drctv.containsKey("echo")) {
      assert drctv["echo"] instanceof Boolean
    }

    if (drctv.containsKey("errorStrategy")) {
      assert drctv["errorStrategy"] instanceof CharSequence
      assert drctv["errorStrategy"] in ["terminate", "finish", "ignore", "retry"] : "Unexpected value for errorStrategy"
    }

    if (drctv.containsKey("executor")) {
      assert drctv["executor"] instanceof CharSequence
      assert drctv["executor"] in ["local", "sge", "uge", "lsf", "slurm", "pbs", "pbspro", "moab", "condor", "nqsii", "ignite", "k8s", "awsbatch", "google-pipelines"] : "Unexpected value for executor"
    }

    if (drctv.containsKey("machineType")) {
      assert drctv["machineType"] instanceof CharSequence
    }

    if (drctv.containsKey("maxErrors")) {
      assert drctv["maxErrors"] instanceof Integer
    }

    if (drctv.containsKey("maxForks")) {
      assert drctv["maxForks"] instanceof Integer
    }

    if (drctv.containsKey("maxRetries")) {
      assert drctv["maxRetries"] instanceof Integer
    }

    if (drctv.containsKey("memory")) {
      assert drctv["memory"] instanceof CharSequence
    }

    if (drctv.containsKey("module")) {
      if (drctv["module"] instanceof List) {
        drctv["module"] = drctv["module"].join(":")
      }
      assert drctv["module"] instanceof CharSequence
    }

    if (drctv.containsKey("penv")) {
      assert drctv["penv"] instanceof CharSequence
    }

    if (drctv.containsKey("pod")) {
      if (drctv["pod"] instanceof Map) {
        drctv["pod"] = [drctv["pod"]]
      }
      assert drctv["pod"] instanceof List
      drctv["pod"].forEach { pod ->
        assert pod instanceof Map
      }
    }

    if (drctv.containsKey("publishDir")) {
      def pblsh = drctv["publishDir"]

      assert pblsh instanceof List || pblsh instanceof Map || pblsh instanceof CharSequence

      pblsh = pblsh instanceof List ? pblsh : [pblsh]

      pblsh = pblsh.collect { elem ->
        elem = elem instanceof CharSequence ? [path: elem] : elem

        assert elem instanceof Map : "Expected publish argument '$elem' to be a String or a Map. Found: class ${elem.getClass()}"
        ConfigUtils.assertMapKeys(elem, ["path", "mode", "overwrite", "pattern", "saveAs", "enabled"], ["path"], "publishDir")

        assert elem.containsKey("path")
        assert elem["path"] instanceof CharSequence
        if (elem.containsKey("mode")) {
          assert elem["mode"] instanceof CharSequence
          assert elem["mode"] in ["symlink", "rellink", "link", "copy", "copyNoFollow", "move"]
        }
        if (elem.containsKey("overwrite")) {
          assert elem["overwrite"] instanceof Boolean
        }
        if (elem.containsKey("pattern")) {
          assert elem["pattern"] instanceof CharSequence
        }
        if (elem.containsKey("saveAs")) {
          assert elem["saveAs"] instanceof CharSequence
        }
        if (elem.containsKey("enabled")) {
          assert elem["enabled"] instanceof Boolean
        }

        elem
      }
      drctv["publishDir"] = pblsh
    }

    if (drctv.containsKey("queue")) {
      if (drctv["queue"] instanceof List) {
        drctv["queue"] = drctv["queue"].join(",")
      }
      assert drctv["queue"] instanceof CharSequence
    }

    if (drctv.containsKey("label")) {
      if (drctv["label"] instanceof CharSequence) {
        drctv["label"] = [drctv["label"]]
      }
      assert drctv["label"] instanceof List
      drctv["label"].forEach { label ->
        assert label instanceof CharSequence
      }
    }

    if (drctv.containsKey("scratch")) {
      assert drctv["scratch"] == true || drctv["scratch"] instanceof CharSequence
    }

    if (drctv.containsKey("storeDir")) {
      assert drctv["storeDir"] instanceof CharSequence
    }

    if (drctv.containsKey("stageInMode")) {
      assert drctv["stageInMode"] instanceof CharSequence
      assert drctv["stageInMode"] in ["copy", "link", "symlink", "rellink"]
    }

    if (drctv.containsKey("stageOutMode")) {
      assert drctv["stageOutMode"] instanceof CharSequence
      assert drctv["stageOutMode"] in ["copy", "move", "rsync"]
    }

    if (drctv.containsKey("tag")) {
      assert drctv["tag"] instanceof CharSequence
    }

    if (drctv.containsKey("time")) {
      assert drctv["time"] instanceof CharSequence
    }

    return drctv
  }
}
