# sbom-pipeline

One pipeline that builds your Docker image, creates an SBOM of everything inside it, and scans that SBOM for known
vulnerabilities. The same shell scripts run on **GitHub Actions** and on **GitLab CI**, so a project on either
platform gets identical behaviour.

By default it only **reports**. Setting one input (`fail-on` / `FAIL_ON`) makes it **block** the pipeline.

> **Status:** work in progress, part of a research project on SBOM tooling in CI/CD.
> The scripts, the GitHub action and the GitLab template have all run successfully: the action on GitHub-hosted runners
> (two services in a matrix) and the template on a GitLab Docker runner. Blocking (`fail-on`) is a plain severity
> threshold, tested in a Linux container only, not yet on a real pipeline.

## What it does

```
Dockerfile ──► build-image.sh ──► image.tar ──► generate-sbom.sh ──► sbom.cdx.json ──► scan-sbom.sh ──► grype.json
               docker build        saved image    Syft (CycloneDX 1.6)                  Grype            + table in the log
```

| Step | Tool | Output |
|---|---|---|
| Build the image | `docker build` + `docker save` | `image.tar` |
| Generate the SBOM | [Syft](https://github.com/anchore/syft) | `sbom.cdx.json` (CycloneDX 1.6), named after the project and commit |
| Scan the SBOM | [Grype](https://github.com/anchore/grype) | table in the job log + `grype.json`, then `grype db status` |

Because it scans the finished **image**, it sees everything that ships: the base OS packages, the Java runtime and
all libraries, not only what the build tool declared. Test-only dependencies are not in the image, so they are not in
the SBOM.

## Requirements

- A **Dockerfile**. The pipeline works on a built image, so the project must ship as a Docker image.
- A Linux amd64 runner with Docker (GitHub-hosted `ubuntu-*` runners work as they are).
- The image name must be lowercase (Docker rule).

It does not care about the language or build tool: Java/Gradle, Node, Python and Go images all work. If your Dockerfile
does not build the application itself, run your own build step before the pipeline so the Dockerfile can copy the result.

## Use it on GitHub

In your project, add a workflow. The `checkout` step comes first because the pipeline builds your repository.

```yaml
# .github/workflows/sbom.yml
name: SBOM and scan
on: [push, pull_request]

permissions:
  contents: read

jobs:
  sbom-scan:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: TimothyThijsen/sbom-pipeline@<commit-sha>
        with:
          image-name: my-service
          # context: services/adapter        # optional, folder with the Dockerfile
          # fail-on: high                    # optional, block on this severity or higher
```

Replace `<commit-sha>` with a full commit SHA of this repo (see [Pinning](#pinning)).

**Two or more services in one repo** (a matrix, one job per service):

```yaml
    strategy:
      matrix:
        service: [holidayadapter, holidayprocessor]
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: TimothyThijsen/sbom-pipeline@<commit-sha>
        with:
          image-name: ${{ matrix.service }}
          context: ${{ matrix.service }}
```

The SBOM and the scan report are uploaded as an artifact named `sbom-<image-name>`.

## Use it on GitLab

Add this to the project's `.gitlab-ci.yml`. The same commit SHA goes in two places, because GitLab only fetches the
YAML, and the jobs download the scripts of that same commit.

```yaml
include:
  - remote: https://raw.githubusercontent.com/TimothyThijsen/sbom-pipeline/<commit-sha>/gitlab/sbom-scan.yml

variables:
  SBOM_PIPELINE_REF: <commit-sha>      # must be the same SHA as in the include URL
  # IMAGE_NAME: my-service             # default: the GitLab project name (must be lowercase)
  # CONTEXT: services/adapter          # default: .
  # FAIL_ON: high                      # default: empty = report only
```

The template defines the stages `build`, `package`, `sbom_generation` and `vulnerability_scan` and the three jobs
`package`, `sbom_generation` and `vulnerability_scan`. If your project has its own build step (tests, a jar), add it
yourself in the `build` stage; its artifacts reach the `package` job automatically.

```yaml
build:
  stage: build
  script: ./gradlew build
  artifacts:
    paths: [build/libs/*.jar]
```

Things to know:

- The `package` job runs `docker build`, so it needs a runner that can reach a Docker daemon. The template uses the
  tag `docker`; override `tags:` on the job if your runner has another tag.
- If the GitLab server cannot reach `raw.githubusercontent.com` (self-hosted or restricted instances), mirror this
  repository to your GitLab and use `include: project:` instead.
- On a runner that binds the Docker socket, the `package` job controls that machine's Docker daemon. Only use it for code
  you trust.

## Inputs

| GitHub input | GitLab variable | Default | Meaning |
|---|---|---|---|
| `image-name` | `IMAGE_NAME` | (required) / project name | Name of the image and of the build in the SBOM |
| `image-tag` | `IMAGE_TAG` | short commit SHA | Tag of the image |
| `context` | `CONTEXT` | `.` | Docker build context |
| `dockerfile` | `DOCKERFILE` | `<context>/Dockerfile` | Path to the Dockerfile |
| `fail-on` | `FAIL_ON` | empty (report only) | `low`, `medium`, `high` or `critical`: fail on this severity or higher |
| `artifact-name` | | `sbom-<image-name>` | Artifact name (GitHub), must be unique per matrix job |
| `retention-days` | | `90` | Artifact retention (GitHub); GitLab keeps the SBOM and report 6 months |
| | `SBOM_PIPELINE_REF` | (required) | Commit SHA of this repo that the GitLab jobs download |

The scripts in `scripts/` read the same values as environment variables (`IMAGE_NAME`, `IMAGE_TAG`, `CONTEXT`,
`DOCKERFILE`, `OUT_DIR`, `FAIL_ON`), so you can also run them locally:

```bash
IMAGE_NAME=my-service IMAGE_TAG=local sh scripts/build-image.sh
IMAGE_NAME=my-service IMAGE_TAG=local sh scripts/install-tools.sh
IMAGE_NAME=my-service IMAGE_TAG=local sh scripts/generate-sbom.sh
sh scripts/scan-sbom.sh
```

## Pinning

Always point to a **full commit SHA**, not to a branch or a tag. A tag can be moved to different code; a commit
SHA cannot. The same rule applies inside this repo: Syft and Grype are downloaded at a fixed version and checked against
a sha256 in `tools.env`, and the third-party action is pinned by commit SHA.

## Updating Syft or Grype

1. Open the release page and copy the `linux_amd64.tar.gz` line from `syft_<version>_checksums.txt` (or `grype_...`).
2. Change the version and the checksum in `tools.env`. This is the only file that needs to change.
3. Run the scripts locally, then publish a new commit and move your projects to the new commit SHA.

If a checksum is wrong, `install-tools.sh` deletes the download and stops with an error before anything runs.

## Known limitations

- Linux amd64 only (no checksums for other platforms in `tools.env` yet).
- The image SBOM has no Go function symbols (CycloneDX drops them), so Grype can report some Go findings that do not apply.
- A severity threshold alone is a crude rule: severity is not the same as risk (exploitability and known exploits matter).
- Results depend on the Grype database of the day; `grype db status` is printed on every run for that reason.

## License

[MIT](LICENSE)
