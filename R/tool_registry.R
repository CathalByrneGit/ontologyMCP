build_tool_registry <- function(concept_ctx) {
  tools <- list(
    list(
      name = "get_ontology_summary",
      description = "Get a high-level summary of the ontology: object type names, row counts, concept counts, and recent actions. Use this as your first call to orient yourself.",
      inputSchema = list(type = "object", properties = list(), required = list())
    ),
    list(
      name = "list_object_types",
      description = "List all object types in the ontology with their properties and source tables. Use this first to understand what data is available before querying.",
      inputSchema = list(type = "object", properties = list(), required = list())
    ),
    list(
      name = "list_link_types",
      description = "List all relationship types between object types. Shows how objects are connected, including cardinality and direction.",
      inputSchema = list(type = "object", properties = list(), required = list())
    ),
    list(
      name = "query_objects",
      description = "Query objects of a specific type with optional filters. Returns matching rows as JSON. Example: query Airport objects where country equals 'Ireland'.",
      inputSchema = list(
        type = "object",
        properties = list(
          object_type_id = list(
            type = "string",
            description = "The ID of the object type to query, e.g. 'Airport'"
          ),
          filters = list(
            type = "array",
            description = "Optional list of property filters.",
            items = list(
              type = "object",
              properties = list(
                property = list(type = "string"),
                op = list(
                  type = "string",
                  `enum` = list("eq", "neq", "gt", "gte", "lt", "lte",
                                "contains", "in", "is_null", "is_not_null")
                ),
                value = list()
              ),
              required = list("property", "op")
            )
          ),
          limit = list(type = "integer", default = 50L),
          select = list(
            type = "array",
            items = list(type = "string"),
            description = "Property IDs to include. Omit for all properties."
          )
        ),
        required = list("object_type_id")
      )
    ),
    list(
      name = "get_object",
      description = "Fetch a single object by its primary key value.",
      inputSchema = list(
        type = "object",
        properties = list(
          object_type_id = list(type = "string"),
          pk_value = list(type = "string", description = "Primary key value as string")
        ),
        required = list("object_type_id", "pk_value")
      )
    ),
    list(
      name = "traverse_links",
      description = "Follow a link from a source object to find related objects. Example: find all FlightRoutes from Airport 'DUB'.",
      inputSchema = list(
        type = "object",
        properties = list(
          object_type_id = list(type = "string"),
          pk_value = list(type = "string"),
          link_type_id = list(type = "string"),
          direction = list(
            type = "string",
            `enum` = list("forward", "reverse"),
            default = "forward",
            description = "forward = follow link from this object; reverse = find objects that link to this one"
          ),
          limit = list(type = "integer", default = 50L)
        ),
        required = list("object_type_id", "pk_value", "link_type_id")
      )
    ),
    list(
      name = "count_objects",
      description = "Count objects matching optional filters. Faster than query_objects when you only need the count.",
      inputSchema = list(
        type = "object",
        properties = list(
          object_type_id = list(type = "string"),
          filters = list(type = "array")
        ),
        required = list("object_type_id")
      )
    ),
    list(
      name = "submit_action",
      description = "Submit an ontology action to modify objects. Always use dry_run=true first to preview what will change.",
      inputSchema = list(
        type = "object",
        properties = list(
          action_type_id = list(type = "string"),
          params = list(type = "object"),
          target_ids = list(type = "array", items = list(type = "string")),
          dry_run = list(type = "boolean", default = TRUE)
        ),
        required = list("action_type_id", "params")
      )
    )
  )

  if (!is.null(concept_ctx)) {
    tools <- c(tools, list(
      list(
        name = "list_concepts",
        description = "List all concept definitions with their current production versions and disagreement rates.",
        inputSchema = list(type = "object", properties = list(), required = list())
      ),
      list(
        name = "evaluate_concept",
        description = "Evaluate a concept definition against all objects of its type. Returns which objects satisfy the concept (true/false per object). Example: evaluate 'high_risk_patient' for scope 'clinical'.",
        inputSchema = list(
          type = "object",
          properties = list(
            concept_id = list(type = "string"),
            scope = list(type = "string"),
            stage = list(
              type = "string",
              `enum` = list("production", "staging"),
              default = "production"
            ),
            limit = list(type = "integer", default = 100L)
          ),
          required = list("concept_id", "scope")
        )
      )
    ))
  }

  tools
}
