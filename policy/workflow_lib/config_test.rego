# The repository's config: parameters that replace the defaults, and
# exceptions by rule, file, job and step. Each test proves the config changes
# a rule's result.
package workflow_config_test

import data.workflow_concurrency
import data.workflow_drafts
import data.workflow_fixtures as f
import data.workflow_labels
import data.workflow_mise_env
import data.workflow_mise_env_test as m
import rego.v1

# The fixture's verify job without its draft skip, and a file-level drafts
# finding from a missing type.
no_skip := f.edited("  verify:\n    if: ${{ !github.event.pull_request.draft }}\n", "  verify:\n")

no_type := f.edited("reopened, ready_for_review", "reopened")

result(lines, config) := {"deny": d, "warn": w} if {
	d := workflow_drafts.deny_drafts with input as lines with data.conftest.file as f.file with data.workflow_policy as config
	w := workflow_drafts.warn_drafts with input as lines with data.conftest.file as f.file with data.workflow_policy as config
}

mise(lines, config) := {"deny": d, "warn": w} if {
	d := workflow_mise_env.deny_mise_env with input as lines with data.conftest.file as f.file with data.workflow_policy as config
	w := workflow_mise_env.warn_mise_env with input as lines with data.conftest.file as f.file with data.workflow_policy as config
}

skip_msg := "job verify must skip drafts with if: ${{ !github.event.pull_request.draft }}, or need a job that does"

test_without_config_the_rule_fails if result(no_skip, {}) == {"deny": {skip_msg}, "warn": set()}

test_file_exception_turns_failure_into_warning if {
	result(no_skip, {"exceptions": [{"rule": "drafts", "file": "ci.yml", "reason": "a reusable caller"}]}) == {"deny": set(), "warn": {concat("", ["excepted (a reusable caller): ", skip_msg])}}
}

test_exception_needs_a_reason if {
	result(no_skip, {"exceptions": [{"rule": "drafts", "file": "ci.yml", "reason": " "}]}).deny == {skip_msg}
}

test_exception_names_its_file if {
	result(no_skip, {"exceptions": [{"rule": "drafts", "file": "release.yml", "reason": "tags only"}]}).deny == {skip_msg}
}

test_exception_names_its_rule if {
	result(no_skip, {"exceptions": [{"rule": "pins", "file": "ci.yml", "reason": "a vendored action"}]}).deny == {skip_msg}
}

test_job_exception_covers_only_its_job if {
	r := result(no_skip, {"exceptions": [{"rule": "drafts", "file": "ci.yml", "job": "changes", "reason": "not this job"}]})
	r.deny == {skip_msg}
	r2 := result(no_skip, {"exceptions": [{"rule": "drafts", "file": "ci.yml", "job": "verify", "reason": "a caller"}]})
	r2.deny == set()
}

# A job exception does not reach a finding the rule reports for the file.
test_job_exception_leaves_file_violations if {
	result(no_type, {"exceptions": [{"rule": "drafts", "file": "ci.yml", "job": "verify", "reason": "a caller"}]}).deny == {"pull_request types must list ready_for_review, so marking a draft ready starts the run"}
}

# The build job's two mise steps: step 2 is the action, step 3 the run.
named_steps := f.lines(replace(
	replace(m.text_with_mise, "      - uses: jdx/mise-action@", "      - id: mise\n        uses: jdx/mise-action@"),
	"      - run: mise install --locked", "      - name: Install tools\n        run: mise install --locked",
))

test_step_exception_by_id_covers_only_that_step if {
	r := mise(named_steps, {"exceptions": [{"rule": "mise_env", "file": "ci.yml", "job": "build", "step": "mise", "reason": "installs nothing"}]})
	r.deny == {"job build, step 3 runs mise without MISE_ENV=ci in its own, its job's or the workflow's env"}
	count(r.warn) == 1
}

test_step_exception_by_name if {
	r := mise(named_steps, {"exceptions": [{"rule": "mise_env", "file": "ci.yml", "job": "build", "step": "Install tools", "reason": "a probe"}]})
	r.deny == {"job build, step 2 runs mise without MISE_ENV=ci in its own, its job's or the workflow's env"}
}

test_step_exception_needs_its_job if {
	r := mise(named_steps, {"exceptions": [{"rule": "mise_env", "file": "ci.yml", "job": "verify", "step": "mise", "reason": "wrong job"}]})
	count(r.deny) == 2
}

# Parameters replace the defaults.
release_env := f.lines(replace(m.text_with_mise, "permissions:\n  contents: read\n", "permissions:\n  contents: read\nenv:\n  MISE_ENV: release\n"))

test_profiles_parameter_changes_the_result if {
	count(mise(release_env, {}).deny) == 2
	count(mise(release_env, {"mise_env": {"profiles": ["ci", "release"]}}).deny) == 0
}

hooks_env := f.lines(replace(m.text_with_mise, "permissions:\n  contents: read\n", "permissions:\n  contents: read\nenv:\n  MISE_ENV: dev,hooks\n"))

test_default_exempt_covers_only_secrets_yml if {
	count(mise(hooks_env, {}).deny) == 2
	count(workflow_mise_env.deny_mise_env) == 0 with input as hooks_env
		with data.conftest.file as {"name": "secrets.yml", "dir": ".github/workflows"}
		with data.workflow_policy as {}
}

test_exempt_parameter_changes_the_result if {
	count(mise(hooks_env, {"mise_env": {"exempt": [{"file": "ci.yml", "profiles": ["dev,hooks"]}]}}).deny) == 0
}

other_runner := f.edited("    runs-on: ubuntu-26.04", "    runs-on: corp-runner-large")

labels_deny(config) := d if {
	d := workflow_labels.deny_labels with input as other_runner
		with data.conftest.file as f.file
		with data["self-hosted-runner"] as f.labels
		with data.workflow_policy as config
}

test_allowed_labels_parameter_changes_the_result if {
	labels_deny({}) == {"job changes runs on corp-runner-large, which is not a GitHub-hosted runner and .github/actionlint.yaml does not list"}
	labels_deny({"labels": {"allowed": ["corp-runner-large"]}}) == set()
}

sha_group := f.edited("|| github.ref_name }}\n", "|| github.ref_name }}-${{ github.sha }}\n")

test_endings_parameter_changes_the_result if {
	count(workflow_concurrency.deny_concurrency) == 1 with input as sha_group with data.conftest.file as f.file
	count(workflow_concurrency.deny_concurrency) == 0 with input as sha_group with data.conftest.file as f.file
		with data.workflow_policy as {"concurrency": {"endings": ["${{ github.sha }}"]}}
}

test_missing_defaults_fail if {
	workflow_drafts.deny_drafts == {"the workflow policy's defaults are not loaded; pass its defaults.yaml with --data"} with input as f.lines(f.workflow)
		with data.conftest.file as f.file
		with data.workflow_policy_defaults as {}
}

# A step names a step only within its job, so a step without a job covers
# nothing.
test_step_exception_without_job_covers_nothing if {
	r := mise(named_steps, {"exceptions": [{"rule": "mise_env", "file": "ci.yml", "step": "mise", "reason": "no job"}]})
	count(r.deny) == 2
	count(r.warn) == 0
}
