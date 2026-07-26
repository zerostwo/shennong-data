# Download a ShennongDB Artifact safely

Same-origin Artifact endpoints use the connection's session bearer
token. A foreign presigned URL is requested without that token, must use
HTTPS, and is followed through a small number of credential-stripping
redirects. Local paths are disabled by default; trusted-local mode
requires explicit opt-in and confinement beneath `local_root`.

## Usage

``` r
sn_download_artifact(
  x,
  artifact,
  path,
  verify = TRUE,
  overwrite = FALSE,
  resume = TRUE,
  allow_large = FALSE,
  trusted_local = FALSE,
  local_root = getOption("ShennongData.trusted_local_root", NULL),
  ...
)
```

## Arguments

- x:

  A
  [ShennongData](https://zerostwo.github.io/shennong-data/reference/ShennongData.md)
  handle.

- artifact:

  An Artifact record or Artifact ID.

- path:

  Destination file.

- verify:

  Whether to verify a declared checksum.

- overwrite:

  Whether to replace an existing destination.

- resume:

  Whether to resume a partial HTTP download.

- allow_large:

  Whether to bypass the configured Artifact-size guard.

- trusted_local:

  Whether a local Artifact path may be read.

- local_root:

  Trusted root directory. Local paths and resolved symlinks must remain
  below this directory.

- ...:

  Reserved for compatible methods.

## Value

`path`, invisibly.
