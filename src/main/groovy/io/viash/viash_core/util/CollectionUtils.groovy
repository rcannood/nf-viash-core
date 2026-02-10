package io.viash.viash_core.util

import java.nio.file.Path

/**
 * Pure utility functions for working with collections, maps, and nested structures.
 * These have no Nextflow dependencies.
 */
class CollectionUtils {

  /**
   * Recursively apply a function over the leaves of an object.
   * Lists and Maps are traversed; all other values are passed to the function.
   *
   * @param obj The object to iterate over.
   * @param fun The function to apply to each leaf value.
   * @return The object with the function applied to each leaf value.
   */
  static Object iterateMap(Object obj, Closure fun) {
    if (obj instanceof List && !(obj instanceof String)) {
      return obj.collect { item ->
        iterateMap(item, fun)
      }
    } else if (obj instanceof Map) {
      return obj.collectEntries { key, item ->
        [key.toString(), iterateMap(item, fun)]
      }
    } else {
      return fun(obj)
    }
  }

  /**
   * Performs a deep clone of the given object.
   * Traverses nested Lists and Maps, cloning Cloneable leaf values.
   *
   * @param x an object
   * @return a deep clone of the object
   */
  static Object deepClone(Object x) {
    iterateMap(x, { it instanceof Cloneable ? it.clone() : it })
  }

  /**
   * Deep-merge two maps. Collections are concatenated, Maps are recursively merged,
   * other values are overwritten by the right-hand side.
   *
   * @param lhs The left-hand side map (base).
   * @param rhs The right-hand side map (overrides).
   * @return A new merged map.
   */
  static Map mergeMap(Map lhs, Map rhs) {
    return rhs.inject(lhs.clone()) { map, entry ->
      if (map[entry.key] instanceof Map && entry.value instanceof Map) {
        map[entry.key] = mergeMap((Map) map[entry.key], (Map) entry.value)
      } else if (map[entry.key] instanceof Collection && entry.value instanceof Collection) {
        map[entry.key] = map[entry.key] + entry.value
      } else {
        map[entry.key] = entry.value
      }
      return map
    }
  }

  /**
   * Collect all File/Path objects from a nested structure (Maps, Lists).
   *
   * @param obj The object to recurse through.
   * @return A flat list of File and Path objects found.
   */
  static List collectFiles(Object obj) {
    if (obj instanceof File || obj instanceof Path) {
      return [obj]
    } else if (obj instanceof List && !(obj instanceof String)) {
      return obj.collectMany { item ->
        collectFiles(item)
      }
    } else if (obj instanceof Map) {
      return obj.collectMany { key, item ->
        collectFiles(item)
      }
    } else {
      return []
    }
  }

  /**
   * Recurse through a state and collect all input files and their target output filenames.
   *
   * @param obj The state to recurse through.
   * @param prefix The prefix to prepend to the output filenames.
   * @return A list of [inputFile, outputFilename] pairs.
   */
  static List collectInputOutputPaths(Object obj, String prefix) {
    if (obj instanceof File || obj instanceof Path) {
      def path = obj instanceof Path ? obj : ((File) obj).toPath()
      def ext = path.getFileName().toString().find(/\.[^.]+$/) ?: ""
      def newFilename = prefix + ext
      return [[obj, newFilename]]
    } else if (obj instanceof List && !(obj instanceof String)) {
      return obj.withIndex().collectMany { item, ix ->
        collectInputOutputPaths(item, prefix + "_" + ix)
      }
    } else if (obj instanceof Map) {
      return obj.collectMany { key, item ->
        collectInputOutputPaths(item, prefix + "." + key)
      }
    } else {
      return []
    }
  }
}
