# ViewDescriptorProtocol.github.io

Documentation site for the [View Descriptor Protocol](https://github.com/ViewDescriptorProtocol/VDP) (VDP), built with [MkDocs Material](https://squidfunk.github.io/mkdocs-material/) and deployed to [vdprotocol.org](https://vdprotocol.org).

## Local Development

**Prerequisites:** Python 3.x

```bash
# Create a virtualenv (optional but recommended)
python -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Start the dev server
make start
```

The site will be available at `http://127.0.0.1:8000`.

## Build

```bash
make build
```

Output is written to the `site/` directory.

## Deployment

Pushes to `main` automatically build and deploy via GitHub Actions to GitHub Pages.

## License

Apache 2.0
