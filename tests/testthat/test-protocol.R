test_that("initialize returns correct protocol version and server info", {
  skip_if_not_installed("duckdb")
  state <- make_test_state()
  resp  <- handle_message(list(jsonrpc = "2.0", id = 1L,
                                method = "initialize", params = list()), state)

  expect_equal(resp$jsonrpc, "2.0")
  expect_equal(resp$id, 1L)
  expect_equal(resp$result$protocolVersion, "2024-11-05")
  expect_equal(resp$result$serverInfo$name, "test-server")
  expect_true(!is.null(resp$result$capabilities$tools))
})

test_that("tools/list returns all base tools with valid schemas", {
  skip_if_not_installed("duckdb")
  state <- make_test_state()
  resp  <- handle_message(list(jsonrpc = "2.0", id = 2L,
                                method = "tools/list", params = list()), state)

  tools <- resp$result$tools
  names <- vapply(tools, `[[`, character(1L), "name")

  expect_true("list_object_types"  %in% names)
  expect_true("list_link_types"    %in% names)
  expect_true("query_objects"      %in% names)
  expect_true("get_object"         %in% names)
  expect_true("traverse_links"     %in% names)
  expect_true("count_objects"      %in% names)
  expect_true("submit_action"      %in% names)
  expect_true("get_ontology_summary" %in% names)

  for (t in tools) {
    expect_true(!is.null(t$inputSchema), info = paste("schema missing for", t$name))
    expect_equal(t$inputSchema$type, "object", info = paste("schema type for", t$name))
  }
})

test_that("concept tools absent when concept_ctx is NULL", {
  skip_if_not_installed("duckdb")
  state <- make_test_state(concept_ctx = NULL)
  resp  <- handle_message(list(jsonrpc = "2.0", id = 3L,
                                method = "tools/list", params = list()), state)
  names <- vapply(resp$result$tools, `[[`, character(1L), "name")
  expect_false("list_concepts"    %in% names)
  expect_false("evaluate_concept" %in% names)
})

test_that("unknown method returns -32601", {
  skip_if_not_installed("duckdb")
  state <- make_test_state()
  resp  <- handle_message(list(jsonrpc = "2.0", id = 4L,
                                method = "banana/split", params = list()), state)
  expect_equal(resp$error$code, -32601L)
})

test_that("ping responds successfully", {
  skip_if_not_installed("duckdb")
  state <- make_test_state()
  resp  <- handle_message(list(jsonrpc = "2.0", id = 5L,
                                method = "ping", params = list()), state)
  expect_null(resp$error)
})
