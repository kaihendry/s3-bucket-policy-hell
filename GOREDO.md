# Goredo Installation

This repository uses [goredo](http://www.goredo.cypherpunks.su/) version 2.6.5 as an alternative build tool to `make`.

## Installation

### Automated Installation with Verification

Run the provided installation script that includes PGP signature verification:

```bash
./install-goredo.sh
```

This script will:
1. Download the meta4 file from: `http://www.goredo.cypherpunks.su/download/goredo-2.6.5.tar.zst.meta4`
2. Import and verify with PGP key: `7531BB84FAF0BF35960C63B93A528DDE952C7E93`
3. Download the goredo tarball
4. Verify the PGP signature
5. Extract and build goredo
6. Install to `$GOPATH/bin` (defaults to `$HOME/go/bin`)

### Requirements

- `curl` - for downloading files
- `gpg` - for PGP signature verification
- `zstd` - for decompressing the tarball
- `tar` - for extracting files
- `go` - for building goredo (version 1.25.4 or later)

### Network Requirements

The installation script requires access to:
- `www.goredo.cypherpunks.su` - for downloading goredo and meta4 file
- `keys.openpgp.org` - for importing the PGP key

If you're behind a corporate firewall or proxy, ensure these domains are accessible.

### Manual Installation

If the automated script fails due to network restrictions, you can manually:

1. Download `goredo-2.6.5.tar.zst` and `goredo-2.6.5.tar.zst.meta4` from the official site
2. Verify the signature manually with GPG
3. Extract and build:
   ```bash
   zstd -d goredo-2.6.5.tar.zst -c | tar -xf -
   cd goredo-2.6.5
   go build -o $GOPATH/bin/goredo
   ```

## Verification

After installation, verify goredo is working:

```bash
goredo -version
```

This should output: `goredo 2.6.5`

## PGP Key Information

The goredo releases are signed with PGP key:
- Key ID: `7531BB84FAF0BF35960C63B93A528DDE952C7E93`
- Owner: goredo maintainer

You can manually verify the key:
```bash
gpg --keyserver hkps://keys.openpgp.org --recv-keys 7531BB84FAF0BF35960C63B93A528DDE952C7E93
gpg --fingerprint 7531BB84FAF0BF35960C63B93A528DDE952C7E93
```

## Usage

Once installed, you can use goredo instead of make:

```bash
goredo target
```

See the [goredo documentation](http://www.goredo.cypherpunks.su/) for more information.
