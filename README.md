# ontologyMCP (retired)

**This package has moved into [ontologyAPI](https://github.com/CathalByrneGit/ontologyAPI).**
This repository is archived and gets no further changes.

ontologyAPI 0.2.0 serves the ontology over both REST and MCP from one shared
set of handlers. Everything ontologyMCP did is there, working against the real
core packages:

| ontologyMCP | ontologyAPI |
|---|---|
| `serve_mcp(bundle, connection, action_ctx, concept_ctx, transport, port, name)` | `serve_mcp(mcp_server(ontology_service(bundle, connection), name), transport, port)`, or `serve_mcp(svc)` |
| the 10 MCP tools | the same 10 tools, now calling the shared handlers |
| `mcp_add_tool()` (called by ontologyDiscoverR, but never defined here) | `ontologyAPI::mcp_add_tool(server, name, description, input_schema, handler)` |

```r
remotes::install_github("CathalByrneGit/ontologyAPI")

con <- DBI::dbConnect(duckdb::duckdb(), "data.duckdb")
svc <- ontologyAPI::ontology_service("bundle.json", con)
ontologyAPI::serve_mcp(svc)   # stdio, for Claude Desktop
```

Claude Desktop config:

```json
{
  "mcpServers": {
    "my-ontology": {
      "command": "Rscript",
      "args": ["-e", "con <- DBI::dbConnect(duckdb::duckdb(), 'data.duckdb'); ontologyAPI::serve_mcp(ontologyAPI::ontology_service('bundle.json', con))"]
    }
  }
}
```

See the [ontologyAPI README](https://github.com/CathalByrneGit/ontologyAPI#readme)
and its NEWS for the full list of changes.
