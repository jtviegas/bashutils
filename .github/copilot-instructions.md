# GitHub Copilot Instructions — bashutils

## Project overview

`bashutils` is a shared bash utility library distributed as a single flat file (`.bashutils`) that is sourced into consumer project scripts. Consumers download a starter script (`bashutils-template.sh`) and call it `helper.sh`; on first run it fetches `.bashutils` from this repo's `master` branch and caches it locally. On subsequent runs it checks for updates at most once per day using `curl -z` (conditional GET) and replaces the local copy only when a newer version exists.

The library is **sourced** — never executed directly. This is a critical constraint for all code you write here (see rules below).

---

## Repository layout

```
bashutils/
├── .bashutils               # GENERATED — derived artifact; do NOT edit directly
├── .bashutils.last_check    # runtime marker; git-ignored
├── .gitignore
├── .variables               # git-ignored; sourced at runtime for shared vars
├── .local_variables         # git-ignored; sourced at runtime for user-local vars
├── .secrets                 # git-ignored; sourced at runtime for credentials
├── bashutils-template.sh    # downloadable consumer starter script (do not break its public API)
├── helper.sh                # this repo's own helper script; also the reference implementation
├── README.md
├── LICENSE
└── sections/                # SOURCE OF TRUTH for .bashutils content
    ├── bash.sh              # foundational utilities (must be first in build order)
    ├── commons.sh           # cheat-sheet printer
    ├── terraform.sh
    ├── js.sh
    ├── aws.sh
    ├── cdk.sh
    ├── python.sh
    ├── azure.sh
    ├── databricks.sh
    └── assorted.sh
```

### Key rule: `.bashutils` is a build artifact

**Always edit `sections/*.sh`, never `.bashutils` directly.**
After changing any section file, rebuild with:

```bash
./helper.sh build_bashutils
```

Then commit **both** the changed section file(s) and the regenerated `.bashutils`.

---

## Coding rules for all bash in this repo

### 1. Use `return`, never `exit`, in library functions

All functions in `sections/*.sh` are sourced into the caller's shell. Using `exit` kills the parent shell session. Always use `return 1` (or `return $?`) on error inside library functions. `exit` is only acceptable at the top-level of `helper.sh`.

```bash
# WRONG — kills the parent shell
some_func() { ... || exit 1; }

# CORRECT
some_func() { ... || return 1; }
```

### 2. Always save and restore the working directory

Any function that calls `cd` must capture the original directory and restore it on all exit paths:

```bash
my_func() {
  local _pwd
  _pwd=$(pwd)
  cd "$some_dir" || return 1
  # ... work ...
  cd "$_pwd"
}
```

### 3. Use indirect expansion for environment-variable checks

`verify_env` (and any similar guard) must check the **value** of the named variable, not the argument string itself:

```bash
# WRONG — tests whether the string "MY_VAR" is empty (it never is)
[ -z "$arg" ]

# CORRECT — tests whether the variable MY_VAR is empty
[ -z "${!arg}" ]
```

### 4. Function documentation header format

Every function must have a header comment block immediately above it:

```bash
############################
#   name: function_name
#   purpose: one-line description
#   parameters: $1 (description), $2 (description), ...  — or "none"
#   returns: exit-code semantics
#   requires: ENV_VAR or global dependencies (omit line if none)
#   side-effects: global variables written (omit line if none)
############################
```

### 5. Logging conventions

Use the four logging helpers defined in `helper.sh`. Always log entry and exit:

```bash
my_func() {
  info "[my_func|in]"
  # ...
  local result="$?"
  local msg="[my_func|out] => ${result}"
  [[ "$result" -ne 0 ]] && err "$msg" && return 1
  info "$msg"
}
```

Available helpers: `info`, `warn`, `err`, `debug`.

### 6. No hardcoded internal URLs or credentials

Do not hardcode company-specific hostnames, internal API endpoints, or credentials. Parameterise via function arguments or environment variables with no default value so callers must supply them explicitly.

### 7. Prefer stdout over global variable side-effects

Functions that compute a value should print it to stdout and return a meaningful exit code, not write to a global variable. This keeps functions composable:

```bash
# CORRECT
get_something() {
  local value
  value=$(compute_it) || return 1
  echo "$value"
}

# caller
result=$(get_something) || exit 1
```

### 8. Section file header format

Every `sections/*.sh` file must start with the canonical three-line section header:

```bash
##########################################
#######    ------- <name> -------   #######
##########################################
```

---

## Section build order

`build_bashutils` currently concatenates `sections/*.sh` in alphabetical glob order. The `bash` section contains foundation functions (`verify_prereqs`, `verify_env`, `info`, `err`, etc.) used by every other section. `bash.sh` sorts 4th alphabetically — this is a known fragility (tracked issue). Until a proper ordering mechanism is in place, **do not introduce top-level executable code** (outside function bodies) in any section file.

---

## Function inventory by section

| Section | Key functions |
|---|---|
| `bash.sh` | `contains`, `verify_prereqs`, `verify_env`, `package`, `create_from_template_and_envvars`, `add_entry_to_file`, `add_entry_to_{variables,local_variables,secrets}`, `git_tag_and_push`, `get_latest_tag`, `changelog`, `proj_code_transfer`, `add_pypi_config`, `assert_uv_config`, `print_uuid` |
| `terraform.sh` | `terraform_autodeploy`, `terraform_autodestroy` |
| `js.sh` | `npm_deps`, `npm_publish` |
| `aws.sh` | `aws_find_kms_alias`, `aws_get_cloudfront_cidr`, `aws_set_profile` |
| `cdk.sh` | `cdk_global_reqs`, `cdk_scaffolding`, `cdk_infra_bootstrap`, `cdk_infra`, `cdk_setup` |
| `python.sh` | `python_build`, `python_test`, `python_code_lint`, `python_code_check`, `python_check_coverage`, `python_reqs`, `python_hatch_build`, `python_hatch_publish`, `poetry_*`, `lint_check_ruff`, `sca_check_safety`, `sast_check_bandit`, and more |
| `azure.sh` | `az_sp_assign_subscription`, `az_sp_login`, `az_login_check`, `az_logout`, `az_list_sp_roles`, `az_storage_account_web_config`, `az_upload_static_website`, `get_azure_access_token` |
| `databricks.sh` | `databricks_set_cli_access`, `databricks_bundle_deploy`, `databricks_bundle_destroy`, `databricks_delete_secret`, `databricks_set_secret`, `get_azure_artifact` |
| `assorted.sh` | `test_js_lambda`, `zip_js_lambda_function`, `get_function_release`, `download_function`, `call_grafana_api` |
| `commons.sh` | `commands` (cheat-sheet printer) |

---

## Known issues (do not introduce regressions)

1. **`verify_env` bug** — currently tests `[ -z "$arg" ]` instead of `[ -z "${!arg}" ]`. Do not copy this pattern.
2. **`aws_set_profile` bug** — `$_pwd` is referenced but never assigned. Any new function using `cd` must assign `_pwd` first.
3. **`exit` vs `return`** — some existing functions still use `exit 1`. Flag these during review; do not add more.
4. **`build_bashutils` ordering** — sections are concatenated alphabetically; foundation `bash.sh` is not first. Do not rely on execution order outside function bodies.
5. **No test harness** — there are no automated tests. When adding or modifying functions, verify manually and consider adding bats-core tests.

---

## Consumer contract (do not break)

- `.bashutils` must be sourceable as-is with `. .bashutils`.
- The public URL `https://raw.githubusercontent.com/jtviegas/bashutils/master/.bashutils` must always serve a valid, sourceable file.
- `bashutils-template.sh` is downloaded by consumers and must remain a self-contained, functional starter script.
- The environment variable names `BASHUTILS_URL`, `BASHUTILS_CHECK_INTERVAL_SECONDS`, `INCLUDE_FILE`, `FILE_VARIABLES`, `FILE_LOCAL_VARIABLES`, `FILE_SECRETS` are part of the public API.

---

## Workflow summary

```
# Edit a section
vim sections/python.sh

# Rebuild .bashutils
./helper.sh build_bashutils

# Verify syntax
bash -n .bashutils

# Commit both files
git add sections/python.sh .bashutils
git commit -m "fix: ..."
```
