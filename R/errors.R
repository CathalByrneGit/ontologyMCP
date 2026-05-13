MCP_PARSE_ERROR     <- -32700L
MCP_INVALID_REQUEST <- -32600L
MCP_METHOD_NOT_FOUND <- -32601L
MCP_INVALID_PARAMS  <- -32602L
MCP_INTERNAL_ERROR  <- -32603L

#' Signal an MCP protocol error
#'
#' Throws a condition caught by handle_message() and converted to a JSON-RPC
#' error response.
#'
#' @param code Integer error code (use MCP_* constants).
#' @param message Human-readable error description.
#' @param data Optional additional data.
#' @noRd
mcp_error <- function(code, message, data = NULL) {
  structure(
    class = c("mcp_error", "error", "condition"),
    list(message = message, code = code, data = data)
  ) |> stop()
}

mcp_error_response <- function(id, code, message, data = NULL) {
  err <- list(code = code, message = message)
  if (!is.null(data)) err$data <- data
  list(jsonrpc = "2.0", id = id, error = err)
}
