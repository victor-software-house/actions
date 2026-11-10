# Workflow policy

One Rego package per rule, which conftest runs over a repository's workflows.
A repository picks the rules it runs.

## Rules

| Package | Requires |
|:--|:--|
| `workflow_drafts` | Draft pull requests run no jobs |
| `workflow_concurrency` | A new push cancels the run it replaces |
| `workflow_labels` | Every runner label is known |
| `workflow_permissions` | The top-level token is read-only |
| `workflow_pins` | Every `uses:` names a full commit SHA and a version comment |
| `workflow_mise_env` | Every step that runs mise loads the `ci` profile |

### workflow_drafts

A workflow on `pull_request` lists `opened`, `synchronize`, `reopened` and `ready_for_review`.
Each job skips drafts with `if: ${{ !github.event.pull_request.draft }}`, or needs a job that does.

### workflow_concurrency

A workflow on `pull_request` groups runs by `${{ github.event.pull_request.number || github.ref_name }}`.
The group may end with `${{ github.event.pull_request.draft && '-draft' || '' }}`, so a draft run never cancels the ready one.
A workflow that also runs on `merge_group` may end its group with the queue expression, which gives every merge queue entry one group per base branch, so a newer entry cancels the runs below it.
The queue merges on the head entry's result alone, and that commit holds every entry below it.
Outside the queue the expression gives the pull request group.
It cancels the run a new push replaces, always or for pull request runs only.

### workflow_labels

Every `runs-on` label is a standard GitHub-hosted runner, or one `.github/actionlint.yaml` lists.
So is every `runner` or `*-runner` input to a reusable workflow.

### workflow_permissions

The top-level `permissions` map each scope to `read` or `none`.
A job that writes maps its own scopes.

### workflow_pins

Every `uses:` names a full commit SHA and a version comment, `# v1.2.3` or `# main, <date>`.

### workflow_mise_env

Every step that runs mise loads the `ci` profile, so a runner never installs the tools of `mise.dev.toml`.
A step runs mise when it uses `jdx/mise-action`, the organization's fork or `mise` action, or names `mise` in its script.

- The nearest `MISE_ENV` decides: the step's, else the job's, else the workflow's.
  It is `ci`, or starts with `ci,`.
- A run script may not override it: no inline `MISE_ENV=` or `$GITHUB_ENV` assignment, no `mise -E` or `--env`, no unset.
- `secrets.yml`, the credential scan, may set `dev,hooks`.

## Usage

A repository needs no copy.
conftest pulls the policy by commit into the git directory and runs the chosen namespaces:

```sh
policy=$(git rev-parse --git-path workflow-policy)
texts=$(git rev-parse --git-path workflow-texts.yaml)
conftest pull --absolute-paths -p "$policy" 'git::https://github.com/victor-software-house/actions.git//policy?ref=<commit>'
sh "$policy/texts.sh" >"$texts"
git ls-files -z ':(glob).github/workflows/*.yml' ':(glob).github/workflows/*.yaml' |
  xargs -0 -r conftest test -p "$policy" -p .github/workflow-policy \
  --data "$policy/defaults.yaml" --data "$texts" \
  --data .github/workflow-policy/config.yaml --data .github/actionlint.yaml \
  --namespace workflow_drafts --namespace workflow_pins
```

- `--absolute-paths` keeps the path whole.
  A linked worktree's git directory is absolute, and conftest would otherwise read it as relative.
- The run takes as data the policy's `defaults.yaml`, the workflows' text, the repository's config and its `actionlint.yaml`.

### Workflow text

`workflow_lib` holds what the rules share.
conftest parses each workflow as YAML, which drops its comments.
So the pins rule reads each file's text from data instead.
`policy/texts.sh`, run from the repository root, writes every workflow's text as YAML under `workflow_texts`.
The pins rule fails when that data is not loaded.

conftest's own ignore parser cannot do this job.
It stops with a panic on any line that ends in a backslash, such as a continued shell command.

## Configuration

Every value a rule compares against is a parameter in `policy/defaults.yaml`, under `workflow_policy_defaults.<rule>.<name>`:

- the draft types and condition;
- the accepted concurrency group endings and `cancel-in-progress` values;
- the hosted and other accepted runner labels;
- the allowed top-level permission levels;
- the pin pattern;
- the accepted mise profiles, and the workflows exempt from them.

A repository replaces one under `workflow_policy.<rule>.<name>` in `.github/workflow-policy/config.yaml`.
The value replaces the default whole, so a list is restated in full.
A rule fails when the defaults are not loaded, instead of passing everything.

### Exceptions

The same file holds the repository's exceptions:

```yaml
workflow_policy:
  mise_env:
    profiles: [ci, release]
  labels:
    allowed: [corp-runner-large]
  exceptions:
    - rule: permissions
      file: release.yml
      reason: publishes the release with the workflow token
    - rule: mise_env
      file: ci.yml
      job: bench
      step: probe
      reason: measures the dev profile's install
```

- Each entry names the rule, the workflow file and a reason.
  An entry with no reason excepts nothing.
- An entry may name a job, and within that job a step by its `id` or `name`.
  A step without its job covers nothing.
- An entry with no job covers the whole file.
- An entry with a job covers only what the rule reports for that job, never a finding about the whole file.
- The pins rule reads lines, so it takes file entries only.
- An excepted finding is reported as a warning that names the reason.

### Repository rules

A repository adds rules as Rego packages beside its config, in `.github/workflow-policy/`.
It names each with another `--namespace`.
They may import `data.workflow_lib` for the parsed workflow, `param` and the exceptions.
