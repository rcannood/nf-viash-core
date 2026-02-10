package io.viash.viash_core.util

import java.nio.file.Path

/**
 * Path resolution and filesystem utilities.
 */
class PathUtils {

  /**
   * Check whether a path string is absolute.
   * Handles URL protocols (e.g., s3://..., gs://..., http://...) as well
   * as standard absolute paths.
   *
   * @param path The path string to check.
   * @return true if the path is absolute.
   */
  static boolean stringIsAbsolutePath(String path) {
    def pattern = ~/^([a-zA-Z][a-zA-Z0-9]*:)?\/.+/
    return pattern.matcher(path).matches()
  }

  /**
   * Resolve a child path relative to a parent.
   * If the child contains a protocol or is absolute, return it unchanged.
   * Otherwise append it to the parent's directory.
   *
   * @param parent The parent path string.
   * @param child The child path string.
   * @return The resolved path string.
   */
  static String getChild(String parent, String child) {
    if (child.contains("://") || java.nio.file.Paths.get(child).isAbsolute()) {
      child
    } else {
      def parentAbsolute = java.nio.file.Paths.get(parent).toAbsolutePath().toString()
      parentAbsolute.replaceAll('/[^/]*$', "/") + child
    }
  }

  /**
   * Recurse upwards until we find a '.build.yaml' file.
   *
   * @param pathPossiblySymlink A path (possibly a symlink) to start from.
   * @return The path to the .build.yaml file, or null if not found.
   */
  static Path findBuildYamlFile(Path pathPossiblySymlink) {
    def path = pathPossiblySymlink.toRealPath()
    def child = path.resolve(".build.yaml")
    if (java.nio.file.Files.isDirectory(path) && java.nio.file.Files.exists(child)) {
      return child
    } else {
      def parent = path.getParent()
      if (parent == null) {
        return null
      } else {
        return findBuildYamlFile(parent)
      }
    }
  }

  /**
   * Get the root of the target folder by finding the directory containing .build.yaml.
   *
   * @param resourcesDir The resources directory to start searching from.
   * @return The parent directory of the .build.yaml file.
   * @throws AssertionError if .build.yaml is not found.
   */
  static Path getRootDir(Path resourcesDir) {
    def dir = findBuildYamlFile(resourcesDir)
    assert dir != null : "Could not find .build.yaml in the folder structure"
    dir.getParent()
  }

  /**
   * Resolve a file path string to a Path, using Nextflow's file() when
   * a session is available, or Paths.get() as a fallback (e.g. in tests).
   *
   * @param path The path string to resolve.
   * @param fileResolver Optional override closure for tests.
   * @return A Path (or whatever the resolver returns).
   */
  static Object resolveFile(String path, Closure fileResolver = null) {
    if (fileResolver != null) {
      return fileResolver(path)
    }
    if (nextflow.Global.session != null) {
      return nextflow.Nextflow.file([hidden: true], path)
    }
    return java.nio.file.Paths.get(path)
  }

  /**
   * Resolve a path relative to a sibling if it's not absolute.
   *
   * @param str The path to resolve (may be a String or any object).
   *        Non-String values are returned as-is.
   * @param parentPath The path to resolve relative to (should have resolveSibling method).
   * @param fileResolver Optional closure to resolve absolute path strings.
   *        If null, uses resolveFile() which delegates to nextflow.Nextflow.file()
   *        or Paths.get() depending on context.
   * @return The resolved path.
   */
  static Object resolveSiblingIfNotAbsolute(Object str, Object parentPath, Closure fileResolver = null) {
    if (!(str instanceof String)) {
      return str
    }
    if (!stringIsAbsolutePath(str)) {
      return parentPath.resolveSibling(str)
    } else {
      return resolveFile(str, fileResolver)
    }
  }
}
