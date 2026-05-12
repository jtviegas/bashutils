# bashutils
bash scripting utilities include file 

## usage

include the file in your bash script:

`. ${this_folder}/.bashutils`

where `this_folder` is the directory containing your script, resolved at runtime with:

```bash
this_folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
```

This variable is already set up for you in the starter script (see below).

## one-liner setup

download a starter script for a new project with:

```bash
curl -fsSL https://raw.githubusercontent.com/jtviegas/bashutils/master/bashutils-template.sh -o ./helper.sh && chmod +x ./helper.sh
```

the downloaded [`bashutils-template.sh`](./bashutils-template.sh) file is a regular bash script that you can rename and customize for your project.

- it creates `.variables`, `.local_variables` and `.secrets` next to the script when needed
- it downloads `.bashutils` on the first run
- on later runs it checks for updates at most once per day and replaces the local `.bashutils` from `master` only when newer
- every downloaded `.bashutils` file is verified with SHA256 using `.bashutils.checksum`
- you can add your own functions directly to the downloaded script and keep reusing the shared `.bashutils`

## starter script structure

the starter script already includes the same header / main / footer layout that was previously shown inline in this README, including a `hello_world` example that you can replace with your own commands.

## notes

- the starter script header tries to:
  - include variables and secrets into the running environment through the files `.variables`, `.local_variables` (for local user specific variables) and `.secrets` in this order 
(these last two _should not be included in versioning_, add them to `.gitignore` file)
  - it also defines handy logging functions
  - ...and downloads the `.bashutils` include file when needed
  - ...and later checks for updates at most once per day, replacing that file from `master` when there is a newer version
  - ...and verifies SHA256 integrity before replacing the local include file
  - ...and gets expected SHA256 from `.bashutils.checksum`
