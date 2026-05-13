test_that("list_object_types returns both types", {
  skip_if_not_installed("duckdb")
  state <- make_test_state()
  resp  <- handle_message(
    list(jsonrpc = "2.0", id = 1L, method = "tools/call",
         params = list(name = "list_object_types", arguments = list())),
    state
  )
  text <- resp$result$content[[1]]$text
  parsed <- jsonlite::fromJSON(text, simplifyVector = FALSE)
  ids <- vapply(parsed, `[[`, character(1L), "id")
  expect_true("Airport" %in% ids)
  expect_true("Airline" %in% ids)
})

test_that("list_link_types returns the aviation link", {
  skip_if_not_installed("duckdb")
  state <- make_test_state()
  resp  <- handle_message(
    list(jsonrpc = "2.0", id = 2L, method = "tools/call",
         params = list(name = "list_link_types", arguments = list())),
    state
  )
  text   <- resp$result$content[[1]]$text
  parsed <- jsonlite::fromJSON(text, simplifyVector = FALSE)
  expect_equal(length(parsed), 1L)
  expect_equal(parsed[[1]]$id, "AirportServedByAirline")
})

test_that("query_objects with eq filter returns correct rows", {
  skip_if_not_installed("duckdb")
  state <- make_test_state()
  resp  <- handle_message(
    list(jsonrpc = "2.0", id = 3L, method = "tools/call",
         params = list(name = "query_objects", arguments = list(
           object_type_id = "Airport",
           filters = list(list(property = "country", op = "eq", value = "Ireland"))
         ))),
    state
  )
  text   <- resp$result$content[[1]]$text
  parsed <- jsonlite::fromJSON(text, simplifyDataFrame = TRUE)
  expect_equal(nrow(parsed), 1L)
  expect_equal(parsed$iata_code, "DUB")
})

test_that("query_objects with contains filter works", {
  skip_if_not_installed("duckdb")
  state <- make_test_state()
  resp  <- handle_message(
    list(jsonrpc = "2.0", id = 4L, method = "tools/call",
         params = list(name = "query_objects", arguments = list(
           object_type_id = "Airport",
           filters = list(list(property = "name", op = "contains", value = "Airport"))
         ))),
    state
  )
  text   <- resp$result$content[[1]]$text
  parsed <- jsonlite::fromJSON(text, simplifyDataFrame = TRUE)
  expect_true(nrow(parsed) >= 2L)
})

test_that("get_object fetches single airport", {
  skip_if_not_installed("duckdb")
  state <- make_test_state()
  resp  <- handle_message(
    list(jsonrpc = "2.0", id = 5L, method = "tools/call",
         params = list(name = "get_object", arguments = list(
           object_type_id = "Airport", pk_value = "LHR"
         ))),
    state
  )
  text   <- resp$result$content[[1]]$text
  parsed <- jsonlite::fromJSON(text, simplifyDataFrame = TRUE)
  expect_equal(parsed$name, "Heathrow Airport")
})

test_that("get_object missing pk returns -32602", {
  skip_if_not_installed("duckdb")
  state <- make_test_state()
  resp  <- handle_message(
    list(jsonrpc = "2.0", id = 6L, method = "tools/call",
         params = list(name = "get_object", arguments = list(
           object_type_id = "Airport", pk_value = "ZZZ"
         ))),
    state
  )
  expect_equal(resp$error$code, -32602L)
})

test_that("count_objects returns correct count", {
  skip_if_not_installed("duckdb")
  state <- make_test_state()
  resp  <- handle_message(
    list(jsonrpc = "2.0", id = 7L, method = "tools/call",
         params = list(name = "count_objects", arguments = list(
           object_type_id = "Airport"
         ))),
    state
  )
  text   <- resp$result$content[[1]]$text
  parsed <- jsonlite::fromJSON(text, simplifyVector = TRUE)
  expect_equal(parsed$count, 4L)
})

test_that("traverse_links forward from DUB returns airlines", {
  skip_if_not_installed("duckdb")
  state <- make_test_state()
  resp  <- handle_message(
    list(jsonrpc = "2.0", id = 8L, method = "tools/call",
         params = list(name = "traverse_links", arguments = list(
           object_type_id = "Airport",
           pk_value       = "DUB",
           link_type_id   = "AirportServedByAirline",
           direction      = "forward"
         ))),
    state
  )
  text   <- resp$result$content[[1]]$text
  parsed <- jsonlite::fromJSON(text, simplifyDataFrame = TRUE)
  expect_equal(nrow(parsed), 2L)
  expect_true("EI" %in% parsed$iata_code)
})

test_that("get_ontology_summary returns bundle_id and object_types", {
  skip_if_not_installed("duckdb")
  state <- make_test_state()
  resp  <- handle_message(
    list(jsonrpc = "2.0", id = 9L, method = "tools/call",
         params = list(name = "get_ontology_summary", arguments = list())),
    state
  )
  text   <- resp$result$content[[1]]$text
  parsed <- jsonlite::fromJSON(text, simplifyVector = FALSE)
  expect_equal(parsed$bundle_id, "aviation-demo")
  expect_true(length(parsed$object_types) >= 1L)
})

test_that("unknown tool name returns -32601", {
  skip_if_not_installed("duckdb")
  state <- make_test_state()
  resp  <- handle_message(
    list(jsonrpc = "2.0", id = 10L, method = "tools/call",
         params = list(name = "nonexistent_tool", arguments = list())),
    state
  )
  expect_equal(resp$error$code, -32601L)
})

test_that("unknown object_type_id returns -32602", {
  skip_if_not_installed("duckdb")
  state <- make_test_state()
  resp  <- handle_message(
    list(jsonrpc = "2.0", id = 11L, method = "tools/call",
         params = list(name = "query_objects", arguments = list(
           object_type_id = "NoSuchType"
         ))),
    state
  )
  expect_equal(resp$error$code, -32602L)
})

test_that("SQL injection in filter value is harmless", {
  skip_if_not_installed("duckdb")
  state <- make_test_state()
  resp  <- handle_message(
    list(jsonrpc = "2.0", id = 12L, method = "tools/call",
         params = list(name = "query_objects", arguments = list(
           object_type_id = "Airport",
           filters = list(list(property = "country", op = "eq",
                               value = "'; DROP TABLE airports; --"))
         ))),
    state
  )
  # Either returns empty result (no match) or an error — table must survive
  cnt_resp <- handle_message(
    list(jsonrpc = "2.0", id = 13L, method = "tools/call",
         params = list(name = "count_objects",
                       arguments = list(object_type_id = "Airport"))),
    state
  )
  text <- cnt_resp$result$content[[1]]$text
  parsed <- jsonlite::fromJSON(text, simplifyVector = TRUE)
  expect_equal(parsed$count, 4L)
})
