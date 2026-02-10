package io.viash.viash_core.util

import java.nio.file.Path

/**
 * Path resolution and filesystem utilities.
 * These are pure Groovy — no Nextflow dependencies.
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
}
