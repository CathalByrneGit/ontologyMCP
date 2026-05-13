test_that("missing method returns -32600", {
  skip_if_not_installed("duckdb")
  state <- make_test_state()
  resp  <- handle_message(list(jsonrpc = "2.0", id = 1L), state)
  expect_equal(resp$error$code, -32600L)
})

test_that("unknown method returns -32601", {
  skip_if_not_installed("duckdb")
  state <- make_test_state()
  resp  <- handle_message(
    list(jsonrpc = "2.0", id = 2L, method = "undefined/method", params = list()),
    state
  )
  expect_equal(resp$error$code, -32601L)
})

test_that("invalid params (bad object type) returns -32602", {
  skip_if_not_installed("duckdb")
  state <- make_test_state()
  resp  <- handle_message(
    list(jsonrpc = "2.0", id = 3L, method = "tools/call",
         params = list(name = "query_objects",
                       arguments = list(object_type_id = "DoesNotExist"))),
    state
  )
  expect_equal(resp$error$code, -32602L)
})

test_that("internal error from bad SQL returns -32603", {
  skip_if_not_installed("duckdb")
  bundle <- make_aviation_bundle()
  # Point a type to a non-existent table to trigger internal error
  bundle$object_types[[1]]$source_table <- "no_such_table"
  con   <- make_test_db()
  state <- make_test_state(bundle = bundle, con = con)

  resp <- handle_message(
    list(jsonrpc = "2.0", id = 4L, method = "tools/call",
         params = list(name = "query_objects",
                       arguments = list(object_type_id = "Airport"))),
    state
  )
  expect_equal(resp$error$code, -32603L)
})

test_that("resources/list returns at least bundle resource", {
  skip_if_not_installed("duckdb")
  state <- make_test_state()
  resp  <- handle_message(
    list(jsonrpc = "2.0", id = 5L, method = "resources/list", params = list()),
    state
  )
  uris <- vapply(resp$result$resources, `[[`, character(1L), "uri")
  expect_true("ontology://bundle" %in% uris)
  expect_true("ontology://schema" %in% uris)
})

test_that("resources/read bundle returns valid JSON", {
  skip_if_not_installed("duckdb")
  state <- make_test_state()
  resp  <- handle_message(
    list(jsonrpc = "2.0", id = 6L, method = "resources/read",
         params = list(uri = "ontology://bundle")),
    state
  )
  text   <- resp$result$contents[[1]]$text
  parsed <- jsonlite::fromJSON(text, simplifyVector = FALSE)
  expect_equal(parsed$id, "aviation-demo")
})

test_that("resources/read unknown URI returns -32602", {
  skip_if_not_installed("duckdb")
  state <- make_test_state()
  resp  <- handle_message(
    list(jsonrpc = "2.0", id = 7L, method = "resources/read",
         params = list(uri = "ontology://nope")),
    state
  )
  expect_equal(resp$error$code, -32602L)
})
