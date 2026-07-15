# Run the ShennongData MCP stdio server

The server reads newline-delimited JSON-RPC from standard input and
writes only MCP messages to standard output. Configure the upstream
instance with `SHENNONG_URL` and an optional `SHENNONG_TOKEN`.

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
