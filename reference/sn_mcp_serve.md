# Run the ShennongData MCP stdio server

The server reads newline-delimited JSON-RPC from standard input and
writes only MCP messages to standard output. Configure the user-facing
Shennong OS/gateway with `SHENNONG_URL`, an optional `SHENNONG_TOKEN`,
and an optional governed `SHENNONG_PROJECT_ID`.

## Usage

``` r
sn_mcp_serve(input = NULL, output = stdout())
```

## Arguments

- input:

  Optional input connection. `NULL` opens the process standard input.

- output:

  Output connection, normally standard output.

## Value

`NULL`, invisibly, when the input stream closes.
