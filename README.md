# bashutils
bash scripting utilities include file 

## usage

### option a) 

include the file in your bash script:

`. ${this_folder}/.bashutils`

where `this_folder` is the directory containing your script, resolved at runtime with:

```bash
this_folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
```

you can also now add the rest of the plumbing, found in the `helper.sh` script below, to be able to update the `.bashutils` file seamlessly.

### option b) 

create a new `helper.sh` script for your project that already includes and updastes `.bashutils` (see [one-liner setup](#one-liner-setup))


## one-liner setup

download a helper script for a new project with:

```bash
curl -fsSL https://raw.githubusercontent.com/jtviegas/bashutils/master/bashutils-template.sh -o ./helper.sh && chmod +x ./helper.sh
```

if eventually you experience issues with the corporation proxy, you still have 2 options:

- try the api:

```bash
curl -fsSL "https://api.github.com/repos/jtviegas/bashutils/contents/bashutils-template.sh" \
  | python3 -c "import sys,json,base64; print(base64.b64decode(json.load(sys.stdin)['content']).decode())" \
    > ./helper.sh && chmod +x ./helper.sh
```

- try using the `gh` cli:

```bash
gh api repos/jtviegas/bashutils/contents/bashutils-template.sh \
  --jq '.content' | base64 -d > ./helper.sh && chmod +x ./helper.sh
```

the downloaded file is a regular bash script that you can rename and customize for your project.

- it creates `.variables`, `.local_variables` and `.secrets` next to the script when needed
- it downloads `.bashutils` on the first run
- it provides a set of logging functions
- on later runs it checks for updates at most once per day and replaces the local `.bashutils` from `master` only when newer
- every downloaded `.bashutils` file is verified with SHA256 using `.bashutils.checksum`
- you can add your own functions directly to the downloaded script and keep reusing the shared `.bashutils`


## contributing

- requirements:
  - bash
  - sha256sum
  - python 3
- treat `sections/` as the source of truth for `.bashutils`
- after updating `sections/`, regenerate `.bashutils` with:

```bash
./helper.sh build_bashutils
```

- commit both the changed `sections/*` source files and the rebuilt `.bashutils` file in the same commit/PR

## tests

this repository uses [bats-core](https://github.com/bats-core/bats-core) for tests:

```bash
bats test
```
