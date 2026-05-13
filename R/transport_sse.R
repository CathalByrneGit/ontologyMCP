run_sse <- function(state, port) {
  if (!requireNamespace("httpuv", quietly = TRUE)) {
    stop("httpuv is required for SSE transport. Install it with install.packages('httpuv').")
  }

  # Each SSE client gets a queue of pending messages.
  clients <- new.env(parent = emptyenv())
  client_counter <- 0L

  app <- list(
    call = function(req) {
      path   <- req$PATH_INFO
      method <- req$REQUEST_METHOD

      if (path == "/sse" && method == "GET") {
        handle_sse_connect(req, clients, state, client_counter)
      } else if (path == "/message" && method == "POST") {
        handle_sse_post(req, clients, state)
      } else {
        list(status = 404L,
             headers = list("Content-Type" = "text/plain"),
             body    = "Not Found")
      }
    },
    onWSOpen  = NULL,
    onWSClose = NULL
  )

  server <- httpuv::startServer("0.0.0.0", port, app)
  cli::cli_alert_info("ontologyMCP SSE transport on port {port}")

  on.exit(httpuv::stopServer(server), add = TRUE)

  while (TRUE) {
    later::run_now(0.1)
    httpuv::service(0L)
  }
}

handle_sse_connect <- function(req, clients, state, counter) {
  client_id <- paste0("c", counter + 1L)

  # SSE response uses a streaming body (httpuv handles this via a connection)
  queue <- list()
  clients[[client_id]] <- list(queue = queue, active = TRUE)

  # Send endpoint event so the client knows where to POST
  endpoint_evt <- sse_event("endpoint", paste0("/message?client_id=", client_id))

  list(
    status  = 200L,
    headers = list(
      "Content-Type"  = "text/event-stream",
      "Cache-Control" = "no-cache",
      "Connection"    = "keep-alive",
      "Access-Control-Allow-Origin" = "*"
    ),
    body = endpoint_evt
  )
}

handle_sse_post <- function(req, clients, state) {
  body <- req$rook.input$read_lines()
  body <- paste(body, collapse = "\n")

  message <- tryCatch(
    jsonlite::fromJSON(body, simplifyVector = FALSE),
    error = function(e) NULL
  )

  if (is.null(message)) {
    return(list(status = 400L,
                headers = list("Content-Type" = "application/json"),
                body = '{"error":"Parse error"}'))
  }

  response <- handle_message(message, state)
  json     <- jsonlite::toJSON(response, auto_unbox = TRUE, null = "null")

  list(
    status  = 200L,
    headers = list("Content-Type" = "application/json",
                   "Access-Control-Allow-Origin" = "*"),
    body    = as.character(json)
  )
}

sse_event <- function(event, data) {
  paste0("event: ", event, "\ndata: ", data, "\n\n")
}
