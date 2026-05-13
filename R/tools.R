tool_get_ontology_summary <- function(args, state) {
  bundle <- state$bundle
  con    <- state$connection

  ot_summary <- lapply(bundle$object_types, function(ot) {
    count <- tryCatch(
      {
        tbl <- ot$source_table %||% ot$id
        DBI::dbGetQuery(con, paste0("SELECT COUNT(*) AS n FROM ", DBI::dbQuoteIdentifier(con, tbl)))$n
      },
      error = function(e) NA_integer_
    )
    list(id = ot$id, display_name = ot$display_name %||% ot$id, row_count = count)
  })

  lt_summary <- lapply(bundle$link_types %||% list(), function(lt) {
    list(id = lt$id, from = lt$from, to = lt$to)
  })

  at_summary <- lapply(bundle$action_types %||% list(), function(at) {
    list(id = at$id, display_name = at$display_name %||% at$id)
  })

  concept_count <- if (!is.null(state$concept_ctx)) {
    tryCatch(length(conceptR::list_concepts(state$concept_ctx)), error = function(e) 0L)
  } else {
    0L
  }

  result <- list(
    bundle_id      = bundle$id %||% "unknown",
    bundle_version = bundle$version %||% "unknown",
    object_types   = ot_summary,
    link_types     = lt_summary,
    action_types   = at_summary,
    concept_count  = concept_count
  )

  mcp_text(jsonlite::toJSON(result, auto_unbox = TRUE, pretty = TRUE))
}

tool_list_object_types <- function(args, state) {
  bundle <- state$bundle
  result <- lapply(bundle$object_types, function(ot) {
    props <- lapply(ot$properties %||% list(), function(p) {
      list(id = p$id, type = p$type %||% "string", nullable = p$nullable %||% TRUE)
    })
    list(
      id           = ot$id,
      display_name = ot$display_name %||% ot$id,
      description  = ot$description %||% "",
      properties   = props,
      source_table = ot$source_table %||% ot$id
    )
  })
  mcp_text(jsonlite::toJSON(result, auto_unbox = TRUE, pretty = TRUE))
}

tool_list_link_types <- function(args, state) {
  result <- lapply(state$bundle$link_types %||% list(), function(lt) {
    list(
      id           = lt$id,
      display_name = lt$display_name %||% lt$id,
      from         = lt$from,
      to           = lt$to,
      cardinality  = lt$cardinality %||% "many_to_many",
      directed     = lt$directed %||% TRUE
    )
  })
  mcp_text(jsonlite::toJSON(result, auto_unbox = TRUE, pretty = TRUE))
}

tool_query_objects <- function(args, state) {
  ot_id   <- args$object_type_id %||% mcp_error(MCP_INVALID_PARAMS, "object_type_id required")
  ot      <- find_object_type(ot_id, state)
  filters <- args$filters %||% list()
  limit   <- as.integer(args$limit %||% 50L)
  select  <- args$select

  tbl_name <- ot$source_table %||% ot$id
  sql      <- build_select_sql(tbl_name, filters, select, limit, state$connection)

  rows <- tryCatch(
    DBI::dbGetQuery(state$connection, sql),
    error = function(e) mcp_error(MCP_INTERNAL_ERROR, conditionMessage(e))
  )

  mcp_text(jsonlite::toJSON(rows, auto_unbox = TRUE, pretty = TRUE))
}

tool_get_object <- function(args, state) {
  ot_id    <- args$object_type_id %||% mcp_error(MCP_INVALID_PARAMS, "object_type_id required")
  pk_value <- args$pk_value        %||% mcp_error(MCP_INVALID_PARAMS, "pk_value required")
  ot       <- find_object_type(ot_id, state)

  pk_col   <- find_pk_column(ot)
  tbl_name <- ot$source_table %||% ot$id
  con      <- state$connection

  sql <- paste0(
    "SELECT * FROM ", DBI::dbQuoteIdentifier(con, tbl_name),
    " WHERE ", DBI::dbQuoteIdentifier(con, pk_col),
    " = ", DBI::dbQuoteLiteral(con, pk_value),
    " LIMIT 1"
  )

  rows <- tryCatch(
    DBI::dbGetQuery(con, sql),
    error = function(e) mcp_error(MCP_INTERNAL_ERROR, conditionMessage(e))
  )

  if (nrow(rows) == 0L) {
    mcp_error(MCP_INVALID_PARAMS,
              paste0("No ", ot_id, " found with pk = ", pk_value))
  }

  mcp_text(jsonlite::toJSON(rows[1, , drop = FALSE], auto_unbox = TRUE, pretty = TRUE))
}

tool_traverse_links <- function(args, state) {
  ot_id    <- args$object_type_id %||% mcp_error(MCP_INVALID_PARAMS, "object_type_id required")
  pk_value <- args$pk_value        %||% mcp_error(MCP_INVALID_PARAMS, "pk_value required")
  lt_id    <- args$link_type_id    %||% mcp_error(MCP_INVALID_PARAMS, "link_type_id required")
  direction <- args$direction      %||% "forward"
  limit     <- as.integer(args$limit %||% 50L)

  lt <- find_link_type(lt_id, state)
  con <- state$connection

  if (direction == "forward") {
    if (lt$from != ot_id) {
      mcp_error(MCP_INVALID_PARAMS,
                paste0("Link ", lt_id, " does not originate from ", ot_id))
    }
    target_ot <- find_object_type(lt$to, state)
    src_ot    <- find_object_type(ot_id, state)
    src_pk    <- find_pk_column(src_ot)

    join_tbl  <- lt$join_table %||% paste0(lt$from, "_", lt$to)
    src_fk    <- lt$from_fk   %||% paste0(lt$from, "_id")
    tgt_fk    <- lt$to_fk     %||% paste0(lt$to, "_id")
    tgt_tbl   <- target_ot$source_table %||% target_ot$id
    tgt_pk    <- find_pk_column(target_ot)

    sql <- paste0(
      "SELECT t.* FROM ",
      DBI::dbQuoteIdentifier(con, tgt_tbl), " t ",
      "JOIN ", DBI::dbQuoteIdentifier(con, join_tbl), " j ",
      "ON t.", DBI::dbQuoteIdentifier(con, tgt_pk),
      " = j.", DBI::dbQuoteIdentifier(con, tgt_fk),
      " WHERE j.", DBI::dbQuoteIdentifier(con, src_fk),
      " = ", DBI::dbQuoteLiteral(con, pk_value),
      " LIMIT ", limit
    )
  } else {
    if (lt$to != ot_id) {
      mcp_error(MCP_INVALID_PARAMS,
                paste0("Link ", lt_id, " does not point to ", ot_id))
    }
    src_ot  <- find_object_type(lt$from, state)
    src_tbl <- src_ot$source_table %||% src_ot$id
    src_pk  <- find_pk_column(src_ot)

    join_tbl <- lt$join_table %||% paste0(lt$from, "_", lt$to)
    src_fk   <- lt$from_fk   %||% paste0(lt$from, "_id")
    tgt_fk   <- lt$to_fk     %||% paste0(lt$to, "_id")

    sql <- paste0(
      "SELECT s.* FROM ",
      DBI::dbQuoteIdentifier(con, src_tbl), " s ",
      "JOIN ", DBI::dbQuoteIdentifier(con, join_tbl), " j ",
      "ON s.", DBI::dbQuoteIdentifier(con, src_pk),
      " = j.", DBI::dbQuoteIdentifier(con, src_fk),
      " WHERE j.", DBI::dbQuoteIdentifier(con, tgt_fk),
      " = ", DBI::dbQuoteLiteral(con, pk_value),
      " LIMIT ", limit
    )
  }

  rows <- tryCatch(
    DBI::dbGetQuery(con, sql),
    error = function(e) mcp_error(MCP_INTERNAL_ERROR, conditionMessage(e))
  )

  mcp_text(jsonlite::toJSON(rows, auto_unbox = TRUE, pretty = TRUE))
}

tool_count_objects <- function(args, state) {
  ot_id   <- args$object_type_id %||% mcp_error(MCP_INVALID_PARAMS, "object_type_id required")
  ot      <- find_object_type(ot_id, state)
  filters <- args$filters %||% list()

  tbl_name <- ot$source_table %||% ot$id
  con      <- state$connection

  where <- build_where_clause(filters, con)
  sql   <- paste0("SELECT COUNT(*) AS n FROM ",
                  DBI::dbQuoteIdentifier(con, tbl_name),
                  if (nchar(where) > 0L) paste0(" WHERE ", where) else "")

  count <- tryCatch(
    DBI::dbGetQuery(con, sql)$n,
    error = function(e) mcp_error(MCP_INTERNAL_ERROR, conditionMessage(e))
  )

  mcp_text(jsonlite::toJSON(list(count = count), auto_unbox = TRUE))
}

tool_list_concepts <- function(args, state) {
  if (is.null(state$concept_ctx)) {
    mcp_error(MCP_INTERNAL_ERROR, "conceptR is not available")
  }
  result <- tryCatch(
    conceptR::list_concepts(state$concept_ctx),
    error = function(e) mcp_error(MCP_INTERNAL_ERROR, conditionMessage(e))
  )
  mcp_text(jsonlite::toJSON(result, auto_unbox = TRUE, pretty = TRUE))
}

tool_evaluate_concept <- function(args, state) {
  if (is.null(state$concept_ctx)) {
    mcp_error(MCP_INTERNAL_ERROR, "conceptR is not available")
  }
  concept_id <- args$concept_id %||% mcp_error(MCP_INVALID_PARAMS, "concept_id required")
  scope      <- args$scope      %||% mcp_error(MCP_INVALID_PARAMS, "scope required")
  stage      <- args$stage      %||% "production"
  limit      <- as.integer(args$limit %||% 100L)

  result <- tryCatch(
    conceptR::evaluate_concept(state$concept_ctx, concept_id, scope,
                               stage = stage, limit = limit),
    error = function(e) mcp_error(MCP_INTERNAL_ERROR, conditionMessage(e))
  )
  mcp_text(jsonlite::toJSON(result, auto_unbox = TRUE, pretty = TRUE))
}

tool_submit_action <- function(args, state) {
  at_id      <- args$action_type_id %||% mcp_error(MCP_INVALID_PARAMS, "action_type_id required")
  params     <- args$params         %||% mcp_error(MCP_INVALID_PARAMS, "params required")
  target_ids <- args$target_ids     %||% list()
  dry_run    <- if (is.null(args$dry_run)) TRUE else isTRUE(args$dry_run)

  result <- tryCatch(
    actionTypesR::submit_action(
      state$action_ctx,
      action_type_id = at_id,
      params         = params,
      target_ids     = target_ids,
      dry_run        = dry_run
    ),
    error = function(e) mcp_error(MCP_INTERNAL_ERROR, conditionMessage(e))
  )

  mcp_text(jsonlite::toJSON(result, auto_unbox = TRUE, pretty = TRUE))
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

mcp_text <- function(text) {
  list(content = list(list(type = "text", text = as.character(text))))
}

`%||%` <- function(a, b) if (!is.null(a)) a else b

find_object_type <- function(id, state) {
  ot <- Filter(function(x) identical(x$id, id), state$bundle$object_types)
  if (length(ot) == 0L) {
    mcp_error(MCP_INVALID_PARAMS, paste0("Unknown object type: ", id))
  }
  ot[[1L]]
}

find_link_type <- function(id, state) {
  lt <- Filter(function(x) identical(x$id, id), state$bundle$link_types %||% list())
  if (length(lt) == 0L) {
    mcp_error(MCP_INVALID_PARAMS, paste0("Unknown link type: ", id))
  }
  lt[[1L]]
}

find_pk_column <- function(ot) {
  pk <- Filter(function(p) isTRUE(p$primary_key), ot$properties %||% list())
  if (length(pk) > 0L) pk[[1L]]$id else "id"
}

build_where_clause <- function(filters, con) {
  if (length(filters) == 0L) return("")
  clauses <- vapply(filters, function(f) {
    col <- DBI::dbQuoteIdentifier(con, f$property)
    op  <- f$op
    val <- f$value

    switch(op,
      eq          = paste0(col, " = ",  DBI::dbQuoteLiteral(con, val)),
      neq         = paste0(col, " != ", DBI::dbQuoteLiteral(con, val)),
      gt          = paste0(col, " > ",  DBI::dbQuoteLiteral(con, val)),
      gte         = paste0(col, " >= ", DBI::dbQuoteLiteral(con, val)),
      lt          = paste0(col, " < ",  DBI::dbQuoteLiteral(con, val)),
      lte         = paste0(col, " <= ", DBI::dbQuoteLiteral(con, val)),
      contains    = paste0(col, " LIKE ", DBI::dbQuoteLiteral(con, paste0("%", val, "%"))),
      `in`        = paste0(col, " IN (",
                           paste(vapply(val, function(v) as.character(DBI::dbQuoteLiteral(con, v)),
                                        character(1L)), collapse = ", "), ")"),
      is_null     = paste0(col, " IS NULL"),
      is_not_null = paste0(col, " IS NOT NULL"),
      mcp_error(MCP_INVALID_PARAMS, paste0("Unknown filter op: ", op))
    )
  }, character(1L))
  paste(clauses, collapse = " AND ")
}

build_select_sql <- function(tbl_name, filters, select_cols, limit, con) {
  cols  <- if (is.null(select_cols) || length(select_cols) == 0L) {
    "*"
  } else {
    paste(vapply(select_cols, function(c) as.character(DBI::dbQuoteIdentifier(con, c)),
                 character(1L)), collapse = ", ")
  }
  where <- build_where_clause(filters, con)
  paste0(
    "SELECT ", cols,
    " FROM ", DBI::dbQuoteIdentifier(con, tbl_name),
    if (nchar(where) > 0L) paste0(" WHERE ", where) else "",
    " LIMIT ", limit
  )
}
