<!-- README.md is generated from README.Rmd. Please edit README.Rmd, not README.md. -->

# ontologyMCP

ontologyMCP implements a [Model Context Protocol](https://spec.modelcontextprotocol.io) (MCP) server that makes your ontology queryable by any LLM agent — Claude, GPT, Cursor, Copilot, LangChain — without writing R code.

    LLM agent (Claude / GPT / LangChain)
            ↕ MCP protocol (JSON-RPC 2.0 over stdio or SSE)
        ontologyMCP
            ↕
        ontologySpecR / objectSetsR / actionTypesR / conceptR

## Installation

``` r
# install.packages("pak")
pak::pkg_install("CathalByrneGit/ontologyMCP")
```

## Quick start

``` r
library(ontologyMCP)

# Load your bundle and open a database connection
bundle <- ontologySpecR::read_bundle("path/to/bundle.json")
con    <- DBI::dbConnect(duckdb::duckdb(), "path/to/data.duckdb")

# Start the MCP server (stdio transport for Claude Desktop)
serve_mcp(bundle, con)
```

## Transports

### stdio (Claude Desktop, local agents)

Pass `transport = "stdio"` (the default). The server reads newline-delimited
JSON-RPC from stdin and writes responses to stdout. All logs go to stderr so
they never corrupt the protocol stream.

``` r
serve_mcp(bundle, con, transport = "stdio")
```

Add the following to your `claude_desktop_config.json` (see
`inst/claude_desktop_config.json` for the full example):

``` json
{
  "mcpServers": {
    "my-ontology": {
      "command": "Rscript",
      "args": ["-e",
        "ontologyMCP::serve_mcp(ontologySpecR::read_bundle('bundle.json'), DBI::dbConnect(duckdb::duckdb(), 'data.duckdb'))"]
    }
  }
}
```

### SSE (web-based agents, remote use)

Pass `transport = "sse"` and optionally `port`. Requires the **httpuv** package.

``` r
serve_mcp(bundle, con, transport = "sse", port = 3000L)
```

The server exposes:

| Endpoint   | Method | Purpose                           |
|------------|--------|-----------------------------------|
| `/sse`     | GET    | SSE stream — server → client messages |
| `/message` | POST   | Client → server messages          |

## Tools

An LLM agent connecting to this server can call the following tools:

| Tool | Description |
|------|-------------|
| `get_ontology_summary` | High-level overview: type names, row counts, action types. Use this first. |
| `list_object_types` | All object types with properties and source tables. |
| `list_link_types` | All relationship types with cardinality and direction. |
| `query_objects` | Query objects with filters (`eq`, `neq`, `gt`, `contains`, `in`, …). |
| `get_object` | Fetch a single object by primary key. |
| `traverse_links` | Follow a link forward or reverse to find related objects. |
| `count_objects` | Count matching objects (faster than a full query). |
| `submit_action` | Submit an action to modify objects. Defaults to `dry_run = TRUE`. |
| `list_concepts` | List concept definitions (requires **conceptR**). |
| `evaluate_concept` | Evaluate a concept against all objects of its type (requires **conceptR**). |

`list_concepts` and `evaluate_concept` are only registered when a
`concept_ctx` is supplied to `serve_mcp()`.

### Filters

The `query_objects` and `count_objects` tools accept a `filters` array:

``` json
[
  { "property": "country", "op": "eq",       "value": "Ireland" },
  { "property": "name",    "op": "contains",  "value": "Airport" },
  { "property": "seats",   "op": "gte",       "value": 200 },
  { "property": "deleted_at", "op": "is_null" }
]
```

Supported operators: `eq`, `neq`, `gt`, `gte`, `lt`, `lte`, `contains`,
`in`, `is_null`, `is_not_null`.

All filter values are passed through `DBI::dbQuoteLiteral()` — SQL injection
is not possible.

## Resources

Three resource URIs are available for agents that support MCP resources:

| URI | Contents |
|-----|----------|
| `ontology://bundle` | Full bundle JSON |
| `ontology://schema` | JSON Schema for the bundle format |
| `ontology://objects/{type_id}/schema` | Property schema for one object type |

## Actions and dry run

`submit_action` always defaults to `dry_run = TRUE`. An agent must
explicitly pass `dry_run: false` to execute a write:

``` json
{
  "name": "submit_action",
  "arguments": {
    "action_type_id": "UpdateAirportName",
    "params": { "name": "Dublin International" },
    "target_ids": ["DUB"],
    "dry_run": false
  }
}
```

## Optional contexts

``` r
serve_mcp(
  bundle,
  con,
  action_ctx  = actionTypesR::ActionContext(...),   # enables submit_action
  concept_ctx = conceptR::ConceptContext(...)        # enables concept tools
)
```

## Testing

Tests use an in-memory DuckDB aviation demo (airports, airlines, a join
table) so no external dependencies are required:

``` r
devtools::test()
```

Key test scenarios covered:

- MCP handshake (`initialize`) returns protocol version `2024-11-05`.
- `tools/list` returns all tools with valid JSON Schemas.
- Concept tools are absent when `concept_ctx = NULL`.
- `query_objects` with `eq` filter returns only matching rows.
- `traverse_links` forward from `DUB` returns two airlines.
- `submit_action` without `dry_run` defaults to `TRUE`.
- SQL injection in a filter value cannot drop tables.
- Unknown method → `-32601`; invalid params → `-32602`; internal error → `-32603`.

## Protocol

Implements MCP version `2024-11-05` (JSON-RPC 2.0). Error codes:

| Code    | Meaning |
|---------|---------|
| -32700  | Parse error |
| -32600  | Invalid request |
| -32601  | Method / tool not found |
| -32602  | Invalid params (unknown type, missing required field) |
| -32603  | Internal error |

## License

MIT
