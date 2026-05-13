handle_resources_list <- function(params, state) {
  bundle <- state$bundle
  base_resources <- list(
    list(
      uri         = "ontology://bundle",
      name        = "Full bundle JSON",
      description = "Complete ontology bundle definition",
      mimeType    = "application/json"
    ),
    list(
      uri         = "ontology://schema",
      name        = "Bundle schema",
      description = "JSON Schema for the bundle format",
      mimeType    = "application/json"
    )
  )

  type_resources <- lapply(bundle$object_types, function(ot) {
    list(
      uri         = paste0("ontology://objects/", ot$id, "/schema"),
      name        = paste0(ot$display_name %||% ot$id, " schema"),
      description = paste0("Property schema for object type: ", ot$id),
      mimeType    = "application/json"
    )
  })

  list(resources = c(base_resources, type_resources))
}

handle_resources_read <- function(params, state) {
  uri <- params$uri %||%
    mcp_error(MCP_INVALID_PARAMS, "uri required")

  if (identical(uri, "ontology://bundle")) {
    content <- jsonlite::toJSON(state$bundle, auto_unbox = TRUE, pretty = TRUE)
    return(list(contents = list(list(uri = uri, mimeType = "application/json",
                                     text = content))))
  }

  if (identical(uri, "ontology://schema")) {
    schema <- bundle_json_schema()
    return(list(contents = list(list(uri = uri, mimeType = "application/json",
                                     text = schema))))
  }

  m <- regmatches(uri, regexpr("^ontology://objects/(.+)/schema$", uri, perl = TRUE))
  if (length(m) == 1L) {
    ot_id <- sub("^ontology://objects/(.+)/schema$", "\\1", uri)
    ot    <- find_object_type(ot_id, state)
    props <- lapply(ot$properties %||% list(), function(p) {
      list(type = p$type %||% "string", nullable = p$nullable %||% TRUE)
    })
    names(props) <- vapply(ot$properties %||% list(), `[[`, character(1L), "id")
    schema_obj <- list(
      `$schema` = "https://json-schema.org/draft/2020-12/schema",
      title      = ot$display_name %||% ot$id,
      type       = "object",
      properties = props
    )
    content <- jsonlite::toJSON(schema_obj, auto_unbox = TRUE, pretty = TRUE)
    return(list(contents = list(list(uri = uri, mimeType = "application/json",
                                     text = content))))
  }

  mcp_error(MCP_INVALID_PARAMS, paste0("Unknown resource URI: ", uri))
}

bundle_json_schema <- function() {
  jsonlite::toJSON(list(
    `$schema` = "https://json-schema.org/draft/2020-12/schema",
    title = "OntologyBundle",
    type  = "object",
    properties = list(
      id           = list(type = "string"),
      version      = list(type = "string"),
      object_types = list(type = "array"),
      link_types   = list(type = "array"),
      action_types = list(type = "array")
    ),
    required = list("id", "object_types")
  ), auto_unbox = TRUE, pretty = TRUE)
}
