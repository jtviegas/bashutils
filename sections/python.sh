##########################################
#######   ------- python -------   #######
##########################################

############################
#   name: python_add_pip_index_to_requirements
#   purpose: prepends an '--extra-index-url' directive to a pip requirements file,
#            preserving the existing content (creates a backup with _old suffix)
#   parameters: $1 (extra index URL), $2 (path to requirements file)
############################
python_add_pip_index_to_requirements(){
  info "[python_add_pip_index_to_requirements|in] ($1, $2)"

  [ -z $1 ] && err "[python_add_pip_index_to_requirements] missing argument EXTRA_INDEX_URL" && exit 1
  local EXTRA_INDEX_URL="$1"
  [ -z $2 ] && err "[python_add_pip_index_to_requirements] missing argument REQS_FILE" && exit 1
  local REQS_FILE="$2"
  local OLD_REQS_FILE="${REQS_FILE}_old"

  cat "$REQS_FILE" > "$OLD_REQS_FILE"
  echo "--extra-index-url $EXTRA_INDEX_URL" > "$REQS_FILE"
  cat "$OLD_REQS_FILE" >> "$REQS_FILE"
  result="$?"

  [ "$result" -ne "0" ] && err "[python_add_pip_index_to_requirements|out] could not add the line" && exit 1
  info "[python_add_pip_index_to_requirements|out] => ${result}"
}

############################
#   name: python_build
#   purpose: builds a Python package (sdist + wheel) using 'python -m build' after cleaning the dist/ directory
#   parameters: none
#   requires: python3 (with build package installed), this_folder
############################

python_build(){
  info "[python_build] ..."

  _pwd=`pwd`
  cd "$this_folder"

  rm -rf dist
  python3 -m build -n
  [ "$?" -ne "0" ] && err "[python_build] ooppss" && exit 1

  cd "$_pwd"
  echo "[python_build] ...done."
}

############################
#   name: python_pypi_publish
#   purpose: uploads all built distributions in dist/ to PyPI using twine
#   parameters: $1 (PyPI username, use '__token__' for token auth), $2 (PyPI password or API token)
#   requires: twine, this_folder
############################

python_pypi_publish(){
  info "[python_pypi_publish|in] ($1, ${2:0:7})"

  [ -z "$2" ] && usage
  [ -z "$1" ] && usage
  user="$1"
  token="$2"

  _pwd=`pwd`
  cd "$this_folder"

  twine upload -u $user -p $token dist/*
  [ "$?" -ne "0" ] && err "[python_pypi_publish] ooppss" && exit 1

  cd "$_pwd"
  echo "[python_pypi_publish|out]"
}

############################
#   name: python_twine_publish
#   purpose: uploads built wheel(s) from dist/ to PyPI or a custom repository using twine
#   parameters: $1 (username), $2 (password or token), $3 (custom repository URL, optional — omit for PyPI)
#   requires: twine, this_folder
############################

python_twine_publish(){
  info "[python_twine_publish|in] ($1, ${2:0:5}, $3)"

  [ -z "$1" ] || [ -z "$2" ] && usage
  user="$1"
  pswd="$2"

  _pwd=`pwd`
  cd "$this_folder"

  if [ ! -z "$3" ]; then
    repo_url="$3" 
    twine upload --verbose -u "${user}" -p "${pswd}" --repository-url "${repo_url}" dist/*.whl 
  else
    twine upload --verbose -u "${user}" -p "${pswd}" dist/*.whl 
  fi

  result=$?
  cd "$_pwd"
  [ "$result" -ne "0" ] && err "[python_twine_publish|out]  => ${result}" && exit 1
  info "[python_twine_publish|out] => ${result}"
}

############################
#   name: python_code_lint
#   purpose: auto-formats Python source code in-place: sorts imports (isort), removes unused imports (autoflake), then reformats (black)
#   parameters: $1 (space-separated source folders, default: 'src test')
#   requires: isort, autoflake, black
############################

python_code_lint()
{
    info "[python_code_lint|in]"

    src_folders="src test"
    if [ ! -z "$1" ]; then
      src_folders="$1"
    fi

    info "[python_code_lint] ... isort..."
    isort --profile black -v $src_folders
    return_value=$?
    info "[python_code_lint] ... isort...$return_value"
    if [ "$return_value" -eq "0" ]; then
      info "[python_code_lint] ... autoflake..."
      autoflake --remove-all-unused-imports --in-place --recursive -r $src_folders
      return_value=$?
      info "[python_code_lint] ... autoflake...$return_value"
    fi
    if [ "$return_value" -eq "0" ]; then
      info "[python_code_lint] ... black..."
      black -v -t py38 $src_folders
      return_value=$?
      info "[python_code_lint] ... black...$return_value"
    fi
    [ "$return_value" -ne "0" ] && exit 1
    info "[python_code_lint|out] => ${return_value}"
    return ${return_value}
}

############################
#   name: python_code_check
#   purpose: runs a full code quality gate (check-only, no modifications): isort, autoflake, black, pylint, bandit;
#            stops at the first tool that reports issues
#   parameters: $1 (space-separated source folders for isort/autoflake/black/pylint, default: 'src test'),
#               $2 (source folder for bandit recursive scan, default: 'src')
#   requires: isort, autoflake, black, pylint, bandit
############################

python_code_check()
{
    info "[python_code_check|in]"

    src_folders="src test"
    if [ ! -z "$1" ]; then
      src_folders="$1"
    fi

    local src_folder="src"
    if [ ! -z "$2" ]; then
      src_folder="$2"
    fi
    
    info "[python_code_check] ... isort..."
    isort --profile black -v $src_folders
    return_value=$?
    info "[python_code_check] ... isort...$return_value"
    if [ "$return_value" -eq "0" ]; then
      info "[python_code_check] ... autoflake..."
      autoflake --check -r $src_folders
      return_value=$?
      info "[python_code_check] ... autoflake...$return_value"
    fi
    if [ "$return_value" -eq "0" ]; then
      info "[python_code_check] ... black..."
      black --check $src_folders
      return_value=$?
      info "[python_code_check] ... black...$return_value"
    fi

    if [ "$return_value" -eq "0" ]; then
      info "[python_code_check] ... pylint..."
      pylint $src_folders
      return_value=$?
      info "[python_code_check] ... pylint...$return_value"
    fi

    if [ "$return_value" -eq "0" ]; then
      info "[python_code_check] ... bandit..."
      bandit -r $src_folder
      return_value=$?
      info "[python_code_check] ... bandit...$return_value"
    fi
   
    [ "$return_value" -ne "0" ] && exit 1
    info "[python_code_check|out] => ${return_value}"
    return ${return_value}
}

############################
#   name: python_print_coverage
#   purpose: prints a terminal coverage report with missing lines using 'coverage report -m'
#   parameters: none
#   requires: coverage
############################

python_print_coverage()
{
  info "[python_print_coverage|in]"
  coverage report -m
  result="$?"
  [ "$result" -ne "0" ] && exit 1
  info "[python_print_coverage|out] => $result"
  return ${result}
}

############################
#   name: python_check_coverage
#   purpose: asserts that the total test coverage percentage meets a minimum threshold; exits with error if below
#   parameters: $1 (minimum coverage percentage, integer, e.g. 80)
#   requires: coverage (with a .coverage data file already generated)
############################

python_check_coverage()
{
  info "[python_check_coverage|in] ($1)"

  [ -z "$1" ] && usage

  local threshold=$1
  score=$(coverage report | awk '$1 == "TOTAL" {print $NF+0}')
   result="$?"
  [ "$result" -ne "0" ] && exit 1
  if (( $threshold > $score )); then
    err "[python_check_coverage] $score doesn't meet $threshold"
    exit 1
  fi
  info "[python_check_coverage|out] => $score"
}

############################
#   name: python_test
#   purpose: runs pytest with verbose output, coverage for the src/ directory, and generates JUnit XML + HTML + XML coverage reports
#   parameters: $1 (test path or file, optional — omit to run all tests)
#   requires: pytest, pytest-cov
############################

python_test()
{
    info "[python_test|in] ($1)"
    python -m pytest -x -s -vv --durations=0 --cov=src --junitxml=tests-results.xml --cov-report=xml --cov-report=html "$1"
    return_value="$?"
    [ "$return_value" -ne "0" ] && exit 1
    info "[python_test|out] => ${return_value}"
    return ${return_value}
}

############################
#   name: python_reqs
#   purpose: installs Python dependencies from a requirements file using pip
#   parameters: $1 (requirements file path, default: requirements.txt)
#   requires: pip
############################

python_reqs()
{
    info "[python_reqs|in] ($1)"

    local REQS_FILE=requirements.txt
    if [ ! -z $1 ]; then
      REQS_FILE="$1"
    fi

    pip install -r "$REQS_FILE"
    [ "$?" -ne "0" ] && exit 1
    info "[python_reqs|out]"
}

############################
#   name: python_hatch_build
#   purpose: cleans dist/ and builds a Python package using 'hatch build'
#   parameters: $1 (project root directory, default: this_folder)
#   requires: hatch
############################

python_hatch_build(){
  echo "[python_hatch_build] ($1)..."

  local ROOT_DIR="$this_folder"
  if [ ! -z $1 ]; then
    ROOT_DIR="$1"
  fi

  _pwd=`pwd`
  cd "$ROOT_DIR"

  rm -rf dist
  hatch build
  if [ ! "$?" -eq "0" ] ; then echo "[python_hatch_build] could not build" && cd "$_pwd" && exit 1; fi

  cd "$_pwd"
  echo "[python_hatch_build] ...done."
}

############################
#   name: python_hatch_publish
#   purpose: publishes the built distributions in dist/ to PyPI using 'hatch publish'
#   parameters: $1 (project root directory, default: this_folder)
#   requires: hatch
############################

python_hatch_publish(){
  echo "[python_hatch_publish] ($1)..."

  local ROOT_DIR="$this_folder"
  if [ ! -z $1 ]; then
    ROOT_DIR="$1"
  fi

  _pwd=`pwd`
  cd "$ROOT_DIR"

  hatch publish -n dist
  if [ ! "$?" -eq "0" ] ; then echo "[python_hatch_publish] could not publish" && cd "$_pwd" && exit 1; fi

  cd "$_pwd"
  echo "[python_hatch_publish] ...done."
}

############################
#   name: build_cookiecutter_template
#   purpose: packages a cookiecutter template directory into a cookiecutter.zip archive placed inside the template folder itself
#   parameters: $1 (path to the cookiecutter template folder)
#   requires: zip
############################

build_cookiecutter_template(){
  info "[build_cookiecutter_template|in] ($1)"
  [[ -z "$1" ]] && err "[build_cookiecutter_template] must provide TEMPLATE_LOCATION folder" && exit 1
  local TEMPLATE_LOCATION="$1"

  [[ ! -d "$TEMPLATE_LOCATION" ]] && err "[build_cookiecutter_template] TEMPLATE_LOCATION folder not found" && exit 1
  local TEMPLATE_NAME=$(basename "$TEMPLATE_LOCATION")
  info "[build_cookiecutter_template|in] template name: $TEMPLATE_NAME"

  _pwd=`pwd`
  cd "$TEMPLATE_LOCATION/.."
  local zipname="cookiecutter.zip"
  local finalzipfile="$TEMPLATE_LOCATION/$zipname"
  rm "$finalzipfile" 2>/dev/null
  zip -r "$zipname" "$TEMPLATE_NAME" --quiet && mv $zipname $finalzipfile
  result="$?"
  cd "$_pwd"
  [ "$result" -ne "0" ] && err "[build_cookiecutter_template|out]  => ${result}" && exit 1
  info "[build_cookiecutter_template|out] => ${result}"
}

############################
#   name: test_cookiecutter_template
#   purpose: generates a project from a cookiecutter template with default values into a test directory,
#            then opens the generated project in VS Code
#   parameters: $1 (path to the cookiecutter template folder), $2 (path to the test output directory)
#   requires: pipx (with cookiecutter), code
############################

test_cookiecutter_template(){
  info "[test_cookiecutter_template|in] ($1, $2)"

  [[ -z "$1" ]] && err "[test_cookiecutter_template] must provide TEMPLATE_LOCATION folder" && exit 1
  local TEMPLATE_LOCATION="$1"

  local TEMPLATE_NAME=$(basename "$TEMPLATE_LOCATION")
  info "[test_cookiecutter_template|in] template name: $TEMPLATE_NAME"

  [[ -z "$2" ]] && err "[test_cookiecutter_template] must provide TEST_LOCATION folder" && exit 1
  local TEST_LOCATION="$2"

  _pwd=`pwd`
  cd "$TEST_LOCATION" && pipx run cookiecutter --no-input "$TEMPLATE_LOCATION"
  result="$?"
  cd "$_pwd"
  info "[test_cookiecutter_template] trying to open vscode on test project: $TEST_LOCATION/$TEMPLATE_NAME"
  code "$TEST_LOCATION/$TEMPLATE_NAME" &
  [ "$result" -ne "0" ] && err "[test_cookiecutter_template|out]  => ${result}" && exit 1
  info "[test_cookiecutter_template|out] => ${result}"
}

############################
#   name: poetry_reqs
#   purpose: installs all project + dev dependencies with poetry and sets up pre-commit hooks
#   parameters: none
#   requires: poetry, pre-commit, this_folder
############################

poetry_reqs(){
  info "[poetry_reqs|in]"
  _pwd=`pwd`
  cd "$this_folder"

  poetry install --with dev && poetry run pre-commit install --install-hooks
  local result="$?"
  if [ ! "$result" -eq "0" ] ; then err "[poetry_reqs] could not install dependencies"; fi

  cd "$_pwd"

  local msg="[poetry_reqs|out] => ${result}"
  [[ ! "$result" -eq "0" ]] && info "$msg" && exit 1
  info "$msg"
}

############################
#   name: lint_check_ruff
#   purpose: runs ruff linter in check mode (no auto-fix) on the project
#   parameters: none
#   requires: poetry (with ruff), this_folder
############################

lint_check_ruff(){
  info "[lint_check_ruff|in]"
  _pwd=`pwd`

  cd "$this_folder"

  poetry run ruff check
  local result="$?"
  if [ ! "$result" -eq "0" ] ; then err "[lint_check_ruff] ruff linter check had issues"; fi

  cd "$_pwd"

  local msg="[lint_check_ruff|out] => ${result}"
  [[ ! "$result" -eq "0" ]] && info "$msg" && exit 1
  info "$msg"
}

############################
#   name: poetry_pytest_unit
#   purpose: runs pytest unit tests via poetry with coverage reporting (term-missing, html, xml) and JUnit XML output
#   parameters: $1 (test folder path), $2 (source folder for coverage, default: this_folder/src)
#   requires: poetry (with pytest, pytest-cov), this_folder
############################

poetry_pytest_unit(){
  info "[poetry_pytest_unit|in] ($1, $2)"

  [[ -z "$1" ]] && err "[poetry_pytest_unit] must provide TEST_FOLDER" && exit 1
  local TEST_FOLDER="$1"
  local SRC_FOLDER="$this_folder/src"
  [[ ! -z "$2" ]] && SRC_FOLDER="$2"


  _pwd=`pwd`
  cd "$this_folder"

  poetry run pytest "$TEST_FOLDER" -x -s -vv --durations=0 \
    --cov="$SRC_FOLDER" \
    --cov-report=term-missing \
    --cov-report=html \
    --cov-report=xml \
    --junitxml=unit-tests-results.xml
  local result="$?"
  [[ ! "$result" -eq "0" ]] && err "[poetry_pytest_unit] tests failed"

  cd "$_pwd"

  local msg="[poetry_pytest_unit|out] => ${result}"
  [[ ! "$result" -eq "0" ]] && info "$msg" && exit 1
  info "$msg"
}

############################
#   name: poetry_pytest_bdd
#   purpose: erases previous coverage data then runs pytest BDD tests via poetry with coverage reporting and JUnit XML output
#   parameters: $1 (BDD test folder path), $2 (source folder for coverage, default: this_folder/src)
#   requires: poetry (with pytest, pytest-cov, pytest-bdd), this_folder
############################

poetry_pytest_bdd(){
  info "[poetry_pytest_bdd|in] ($1)"

  [[ -z "$1" ]] && err "[poetry_pytest_bdd] must provide TEST_FOLDER" && exit 1
  local TEST_FOLDER="$1"
  local SRC_FOLDER="$this_folder/src"
  [[ ! -z "$2" ]] && SRC_FOLDER="$2"

  _pwd=`pwd`
  cd "$this_folder"
  # Clear existing coverage and run BDD tests
  poetry run coverage erase
  poetry run pytest "$TEST_FOLDER" -x -s -vv --durations=0 \
    --cov="$SRC_FOLDER" \
    --cov-report=term-missing \
    --cov-report=html \
    --cov-report=xml \
    --junitxml=bdd-tests-results.xml
  local result="$?"
  [[ ! "$result" -eq "0" ]] && err "[poetry_pytest_bdd] tests failed"

  cd "$_pwd"

  local msg="[poetry_pytest_bdd|out] => ${result}"
  [[ ! "$result" -eq "0" ]] && info "$msg" && exit 1
  info "$msg"
}

############################
#   name: python_poetry_print_coverage
#   purpose: prints a coverage report with missing lines and generates html + xml reports via poetry
#   parameters: none
#   requires: poetry (with coverage)
############################

python_poetry_print_coverage()
{
  info "[python_poetry_print_coverage|in]"
  
  poetry run coverage report --show-missing
  poetry run coverage html
  poetry run coverage xml
  result="$?"
  [ "$result" -ne "0" ] && exit 1
  info "[python_poetry_print_coverage|out] => $result"
  return ${result}
}

############################
#   name: python_poetry_check_coverage
#   purpose: asserts that the total coverage percentage from 'poetry run coverage report' meets a minimum threshold; exits with error if below
#   parameters: $1 (minimum coverage percentage, integer, e.g. 80)
#   requires: poetry (with coverage, and a .coverage data file already generated)
############################

python_poetry_check_coverage()
{
  info "[python_poetry_check_coverage|in] ($1)"
  [ -z "$1" ] && usage

  local threshold=$1
  score=$(poetry run coverage report | awk '$1 == "TOTAL" {print $NF+0}')
  result="$?"
  [ "$result" -ne "0" ] && exit 1
  if (( $threshold > $score )); then
    err "[python_poetry_check_coverage] $score doesn't meet $threshold"
    exit 1
  fi
  info "[python_poetry_check_coverage|out] => $score"
}

############################
#   name: poetry_build
#   purpose: generates a CHANGELOG, cleans dist/ and builds the package using 'poetry build'
#   parameters: none
#   requires: poetry, changelog function, this_folder
############################

poetry_build(){
  info "[poetry_build|in]"
  _pwd=`pwd`
  cd "$this_folder"
  changelog
  rm -rf dist/*
  poetry build
  local result="$?"
  [[ ! "$result" -eq "0" ]] && err "[poetry_build] build failed"

  cd "$_pwd"
  local msg="[poetry_build|out] => ${result}"
  [[ ! "$result" -eq "0" ]] && info "$msg" && exit 1
  info "$msg"
}

############################
#   name: poetry_publish_az
#   purpose: configures a private Azure DevOps PyPI feed in poetry and publishes the package to it
#   parameters: $1 (Azure DevOps feed URL), $2 (poetry repository name/alias), $3 (feed username), $4 (feed password/token)
#   requires: poetry, this_folder
############################

poetry_publish_az(){
  info "[poetry_publish_az|in]"

  [ -z $1 ] && err "[poetry_publish_az] missing argument REPO_URL" && exit 1
  local REPO_URL="$1"
  [ -z $2 ] && err "[poetry_publish_az] missing argument REPO_NAME" && exit 1
  local REPO_NAME="$2"
  [ -z $3 ] && err "[poetry_publish_az] missing argument REPO_USER" && exit 1
  local REPO_USER="$3"
  [ -z $4 ] && err "[poetry_publish_az] missing argument REPO_PSWD" && exit 1
  local REPO_PSWD="$4"
  
  _pwd=`pwd`
  cd "$this_folder"

  poetry config "repositories.${REPO_NAME}" "$REPO_URL"
  poetry config "http-basic.${REPO_NAME}" "$REPO_USER" "$REPO_PSWD"
  poetry publish -r "$REPO_NAME"
  local result="$?"
  [[ ! "$result" -eq "0" ]] && err "[poetry_publish_az] publish failed"

  cd "$_pwd"
  local msg="[poetry_publish_az|out] => ${result}"
  [[ ! "$result" -eq "0" ]] && info "$msg" && exit 1
  info "$msg"
}

############################
#   name: poetry_add_supplemental_source_repo
#   purpose: registers a supplemental (low-priority) private package source in the project's poetry config with authentication
#   parameters: $1 (repository alias/name), $2 (repository URL), $3 (username), $4 (access token)
#   requires: poetry, this_folder
############################

poetry_add_supplemental_source_repo(){
  info "[poetry_add_supplemental_source_repo|in]"
  _pwd=`pwd`
  cd "$this_folder"

  [ -z $1 ] && err "[poetry_add_supplemental_source_repo] missing argument REPO_NAME" && exit 1
  local REPO_NAME="$1"
  [ -z $2 ] && err "[poetry_add_supplemental_source_repo] missing argument REPO_URL" && exit 1
  local REPO_URL="$2"
  [ -z $3 ] && err "[poetry_add_supplemental_source_repo] missing argument REPO_USR" && exit 1
  local REPO_USR="$3"
  [ -z $4 ] && err "[poetry_add_supplemental_source_repo] missing argument REPO_TOKEN" && exit 1
  local REPO_TOKEN="$4"

  poetry source add --priority=supplemental "$REPO_NAME" "$REPO_URL" && \
    poetry config "http-basic.${REPO_NAME}" "$REPO_USR" "$REPO_TOKEN"
  local result="$?"

  cd "$_pwd"
  local msg="[poetry_add_supplemental_source_repo|out] => ${result}"
  [[ ! "$result" -eq "0" ]] && info "$msg" && exit 1
  info "$msg"
}

############################
#   name: sca_check_safety
#   purpose: runs a Software Composition Analysis (SCA) scan with the safety tool to detect known vulnerabilities in dependencies
#   parameters: $1 (Safety CLI API key)
#   requires: poetry (with safety), this_folder
############################

sca_check_safety(){
  info "[sca_check_safety|in] (${1:0:3})"
  _pwd=`pwd`

  [ -z $1 ] && err "[sca_check_safety] missing argument SAFETY_KEY" && exit 1
  local SAFETY_KEY="$1"

  cd "$this_folder"

  poetry run safety --key "$SAFETY_KEY" scan
  local result="$?"
  if [ ! "$result" -eq "0" ] ; then err "[sca_check_safety] code check had issues"; fi

  cd "$_pwd"

  local msg="[sca_check_safety|out] => ${result}"
  [[ ! "$result" -eq "0" ]] && info "$msg" && exit 1
  info "$msg"
}

############################
#   name: sast_check_bandit
#   purpose: runs a Static Application Security Testing (SAST) scan with bandit to detect common security issues in Python source code
#   parameters: $1 (source directory to scan recursively)
#   requires: poetry (with bandit), this_folder
############################

sast_check_bandit(){
  info "[sast_check_bandit|in] ($1)"
  _pwd=`pwd`

  [ -z $1 ] && err "[sast_check_bandit] missing argument SRC_DIR" && exit 1
  local SRC_DIR="$1"

  cd "$this_folder"

  poetry run bandit -r $SRC_DIR
  local result="$?"
  if [ ! "$result" -eq "0" ] ; then err "[sast_check_bandit] code check had issues"; fi

  cd "$_pwd"

  local msg="[sast_check_bandit|out] => ${result}"
  [[ ! "$result" -eq "0" ]] && info "$msg" && exit 1
  info "$msg"
}

############################
#   name: poetry_publish_pip
#   purpose: publishes the built package to PyPI using 'poetry publish' with explicit credentials
#   parameters: $1 (PyPI username, use '__token__' for token auth), $2 (PyPI password or API token)
#   requires: poetry, this_folder
############################

poetry_publish_pip(){
  info "[poetry_publish_pip|in] ($1, ${2:0:7})"

  [ -z $1 ] && err "[poetry_publish_pip] missing argument PYPI_USER" && exit 1
  local PYPI_USER="$1"
  [ -z $2 ] && err "[poetry_publish_pip] missing argument PYPI_TOKEN" && exit 1
  local PYPI_TOKEN="$2"
  
  _pwd=`pwd`
  cd "$this_folder"

  poetry publish -u "$PYPI_USER" -p "$PYPI_TOKEN"
  local result="$?"
  [[ ! "$result" -eq "0" ]] && err "[poetry_publish_pip] publish failed"

  cd "$_pwd"
  local msg="[poetry_publish_pip|out] => ${result}"
  [[ ! "$result" -eq "0" ]] && info "$msg" && exit 1
  info "$msg"
}
