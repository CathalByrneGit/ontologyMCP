test_that("submit_action with dry_run omitted defaults to TRUE", {
  skip_if_not_installed("duckdb")

  # Provide a mock action_ctx that records calls
  calls <- list()
  mock_action_ctx <- structure(list(), class = "MockActionCtx")

  # We test that dry_run=TRUE is passed by mocking actionTypesR::submit_action
  local_mocked_bindings(
    .package = "actionTypesR",
    submit_action = function(ctx, action_type_id, params, target_ids, dry_run) {
      calls[[length(calls) + 1L]] <<- list(dry_run = dry_run)
      list(dry_run = dry_run, preview = list())
    },
    {
      state <- make_test_state()
      state$action_ctx <- mock_action_ctx
      resp <- handle_message(
        list(jsonrpc = "2.0", id = 1L, method = "tools/call",
             params = list(name = "submit_action", arguments = list(
               action_type_id = "UpdateAirportName",
               params = list(name = "New Name")
             ))),
        state
      )
      expect_null(resp$error)
      expect_equal(calls[[1]]$dry_run, TRUE)
    }
  )
})

test_that("submit_action with dry_run=FALSE passes FALSE", {
  skip_if_not_installed("duckdb")

  calls <- list()
  mock_action_ctx <- structure(list(), class = "MockActionCtx")

  local_mocked_bindings(
    .package = "actionTypesR",
    submit_action = function(ctx, action_type_id, params, target_ids, dry_run) {
      calls[[length(calls) + 1L]] <<- list(dry_run = dry_run)
      list(dry_run = dry_run, submission_id = "abc-123")
    },
    {
      state <- make_test_state()
      state$action_ctx <- mock_action_ctx
      resp <- handle_message(
        list(jsonrpc = "2.0", id = 2L, method = "tools/call",
             params = list(name = "submit_action", arguments = list(
               action_type_id = "UpdateAirportName",
               params  = list(name = "New Name"),
               dry_run = FALSE
             ))),
        state
      )
      expect_null(resp$error)
      expect_equal(calls[[1]]$dry_run, FALSE)
    }
  )
})
