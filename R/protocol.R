MCP_PROTOCOL_VERSION <- "2024-11-05"

#' Dispatch a single JSON-RPC message to the appropriate handler
#'
#' @param message Parsed list (from jsonlite::fromJSON).
#' @param state Server state list.
#' @return Named list representing the JSON-RPC response.
#' @noRd
handle_message <- function(message, state) {
  id     <- message$id
  method <- message$method
  params <- message$params %||% list()

  if (is.null(method)) {
    return(mcp_error_response(id, MCP_INVALID_REQUEST, "Missing method"))
  }

  tryCatch(
    {
      result <- switch(method,
        "initialize"       = handle_initialize(params, state),
        "tools/list"       = handle_tools_list(params, state),
        "tools/call"       = handle_tools_call(params, state),
        "resources/list"   = handle_resources_list(params, state),
        "resources/read"   = handle_resources_read(params, state),
        "notifications/initialized" = NULL,
        "ping"             = list(),
        mcp_error(MCP_METHOD_NOT_FOUND, paste0("Unknown method: ", method))
      )

      if (is.null(result) && method == "notifications/initialized") {
        return(invisible(NULL))
      }

      list(jsonrpc = "2.0", id = id, result = result)
    },
    mcp_error = function(e) {
      mcp_error_response(id, e$code, e$message, e$data)
    },
    error = function(e) {
      mcp_error_response(id, MCP_INTERNAL_ERROR, conditionMessage(e))
    }
  )
}

handle_initialize <- function(params, state) {
  list(
    protocolVersion = MCP_PROTOCOL_VERSION,
    capabilities = list(
      tools     = list(listChanged = FALSE),
      resources = list(listChanged = FALSE)
    ),
    serverInfo = list(
      name    = state$name,
      version = utils::packageVersion("ontologyMCP") |> as.character()
    )
  )
}

handle_tools_list <- function(params, state) {
  list(tools = state$tools)
}

handle_tools_call <- function(params, state) {
  tool_name <- params$name %||%
    mcp_error(MCP_INVALID_PARAMS, "Tool name required")
  args <- params$arguments %||% list()

  fn <- state$tool_fns[[tool_name]]
  if (is.null(fn)) {
    mcp_error(MCP_METHOD_NOT_FOUND, paste0("Unknown tool: ", tool_name))
  }

  fn(args, state)
}
