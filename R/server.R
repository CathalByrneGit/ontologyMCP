#' Start the ontology MCP server
#'
#' Implements the Model Context Protocol over stdio (default) or SSE.
#'
#' @param bundle An ontologySpecR bundle (list with object_types, link_types, etc.).
#' @param connection A DBI connection.
#' @param action_ctx An actionTypesR ActionContext or NULL.
#' @param concept_ctx A conceptR ConceptContext or NULL.
#' @param transport One of `"stdio"` (for Claude Desktop) or `"sse"` (HTTP/SSE).
#' @param port Integer. Port for SSE transport (default 3000).
#' @param name Character. Server name reported in the initialize handshake.
#' @export
serve_mcp <- function(bundle, connection,
                       action_ctx = NULL,
                       concept_ctx = NULL,
                       transport = c("stdio", "sse"),
                       port = 3000L,
                       name = "ontologyMCP") {
  transport <- match.arg(transport)

  tools <- build_tool_registry(concept_ctx)

  tool_fns <- list(
    get_ontology_summary = tool_get_ontology_summary,
    list_object_types    = tool_list_object_types,
    list_link_types      = tool_list_link_types,
    query_objects        = tool_query_objects,
    get_object           = tool_get_object,
    traverse_links       = tool_traverse_links,
    count_objects        = tool_count_objects,
    submit_action        = tool_submit_action
  )

  if (!is.null(concept_ctx)) {
    tool_fns$list_concepts    <- tool_list_concepts
    tool_fns$evaluate_concept <- tool_evaluate_concept
  }

  state <- list(
    bundle     = bundle,
    connection = connection,
    action_ctx = action_ctx,
    concept_ctx = concept_ctx,
    tools      = tools,
    tool_fns   = tool_fns,
    name       = name
  )

  switch(transport,
    stdio = run_stdio(state),
    sse   = run_sse(state, port)
  )

  invisible(NULL)
}
