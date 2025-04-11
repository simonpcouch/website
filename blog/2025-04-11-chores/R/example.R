#' Get value of environment variable
#'
#' @param name A single string.
#' @param error_call A call to mention in error messages. Optional.
#'
#' @returns
#' The value of the environment variable if found. Otherwise, the function
#' will error.
#'
#' @export
key_get <- function(name, error_call = caller_env()) {
  val <- Sys.getenv(name)
  if (!identical(val, "")) {
    val
  } else {
    cli::cli_abort(
      "Can't find env var {.envvar {name}}.",
      call = error_call
    )
  }
}
