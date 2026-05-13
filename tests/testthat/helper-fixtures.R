make_aviation_bundle <- function() {
  list(
    id      = "aviation-demo",
    version = "0.1.0",
    object_types = list(
      list(
        id           = "Airport",
        display_name = "Airport",
        description  = "An airport",
        source_table = "airports",
        properties   = list(
          list(id = "iata_code",   type = "string",  primary_key = TRUE,  nullable = FALSE),
          list(id = "name",        type = "string",  primary_key = FALSE, nullable = FALSE),
          list(id = "country",     type = "string",  primary_key = FALSE, nullable = TRUE),
          list(id = "latitude",    type = "numeric", primary_key = FALSE, nullable = TRUE),
          list(id = "longitude",   type = "numeric", primary_key = FALSE, nullable = TRUE)
        )
      ),
      list(
        id           = "Airline",
        display_name = "Airline",
        description  = "An airline",
        source_table = "airlines",
        properties   = list(
          list(id = "iata_code",   type = "string", primary_key = TRUE,  nullable = FALSE),
          list(id = "name",        type = "string", primary_key = FALSE, nullable = FALSE),
          list(id = "country",     type = "string", primary_key = FALSE, nullable = TRUE)
        )
      )
    ),
    link_types = list(
      list(
        id          = "AirportServedByAirline",
        display_name = "Airport Served By Airline",
        from        = "Airport",
        to          = "Airline",
        cardinality = "many_to_many",
        directed    = TRUE,
        join_table  = "airport_airlines",
        from_fk     = "airport_id",
        to_fk       = "airline_id"
      )
    ),
    action_types = list(
      list(id = "UpdateAirportName", display_name = "Update Airport Name")
    )
  )
}

make_test_db <- function() {
  con <- DBI::dbConnect(duckdb::duckdb(), ":memory:")
  DBI::dbExecute(con, "
    CREATE TABLE airports (
      iata_code VARCHAR PRIMARY KEY,
      name VARCHAR NOT NULL,
      country VARCHAR,
      latitude DOUBLE,
      longitude DOUBLE
    )
  ")
  DBI::dbExecute(con, "
    INSERT INTO airports VALUES
      ('DUB', 'Dublin Airport', 'Ireland', 53.421, -6.270),
      ('LHR', 'Heathrow Airport', 'United Kingdom', 51.477, -0.461),
      ('CDG', 'Charles de Gaulle', 'France', 49.009, 2.551),
      ('JFK', 'John F Kennedy', 'United States', 40.640, -73.779)
  ")
  DBI::dbExecute(con, "
    CREATE TABLE airlines (
      iata_code VARCHAR PRIMARY KEY,
      name VARCHAR NOT NULL,
      country VARCHAR
    )
  ")
  DBI::dbExecute(con, "
    INSERT INTO airlines VALUES
      ('EI', 'Aer Lingus', 'Ireland'),
      ('BA', 'British Airways', 'United Kingdom'),
      ('AF', 'Air France', 'France')
  ")
  DBI::dbExecute(con, "
    CREATE TABLE airport_airlines (
      airport_id VARCHAR,
      airline_id VARCHAR
    )
  ")
  DBI::dbExecute(con, "
    INSERT INTO airport_airlines VALUES
      ('DUB', 'EI'),
      ('DUB', 'BA'),
      ('LHR', 'BA'),
      ('CDG', 'AF')
  ")
  con
}

make_test_state <- function(bundle = NULL, con = NULL, concept_ctx = NULL) {
  if (is.null(bundle)) bundle <- make_aviation_bundle()
  if (is.null(con))    con    <- make_test_db()

  tools    <- build_tool_registry(concept_ctx)
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

  list(
    bundle      = bundle,
    connection  = con,
    action_ctx  = NULL,
    concept_ctx = concept_ctx,
    tools       = tools,
    tool_fns    = tool_fns,
    name        = "test-server"
  )
}
