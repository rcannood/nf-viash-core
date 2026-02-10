package io.viash.viash_core.config

/**
 * Exception thrown when an argument value does not match its expected type.
 */
class UnexpectedArgumentTypeException extends Exception {
  String errorIdentifier
  String stage
  String plainName
  String expectedClass
  String foundClass

  UnexpectedArgumentTypeException(String errorIdentifier, String stage, String plainName, String expectedClass, String foundClass) {
    super("Error${errorIdentifier ? " $errorIdentifier" : ""}:${stage ? " $stage" : ""} argument '${plainName}' has the wrong type. " +
      "Expected type: ${expectedClass}. Found type: ${foundClass}")
    this.errorIdentifier = errorIdentifier
    this.stage = stage
    this.plainName = plainName
    this.expectedClass = expectedClass
    this.foundClass = foundClass
  }
}
