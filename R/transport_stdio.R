run_stdio <- function(state) {
  con_in  <- file("stdin",  open = "r", blocking = TRUE)
  on.exit(close(con_in), add = TRUE)

  cli::cli_alert_info("ontologyMCP stdio transport ready", .envir = globalenv())

  repeat {
    line <- tryCatch(readLines(con_in, n = 1L, warn = FALSE),
                     error = function(e) character(0L))

    if (length(line) == 0L || identical(line, character(0L))) break
    line <- trimws(line)
    if (nchar(line) == 0L) next

    message <- tryCatch(
      jsonlite::fromJSON(line, simplifyVector = FALSE),
      error = function(e) {
        write_stdout(mcp_error_response(NULL, MCP_PARSE_ERROR, "Parse error"))
        NULL
      }
    )
    if (is.null(message)) next

    response <- handle_message(message, state)
    if (!is.null(response)) write_stdout(response)
  }

  invisible(NULL)
}

write_stdout <- function(response) {
  json <- jsonlite::toJSON(response, auto_unbox = TRUE, null = "null")
  cat(json, "\n", sep = "", file = stdout())
  flush(stdout())
}
