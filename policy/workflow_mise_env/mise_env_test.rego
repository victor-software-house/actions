package workflow_mise_env_test

import data.workflow_fixtures as f
import data.workflow_mise_env
import rego.v1

denied(input_lines) := result if {
	result := workflow_mise_env.deny_mise_env with input as input_lines with data.conftest.file as f.file
}

# The build job's mise steps, appended to the fixture's own steps.
mise_steps := `
      - uses: jdx/mise-action@6612f0ef07ed2a736cd1e00a94a065522dd41195 # v4.0.1
      - run: mise install --locked`

with_mise := f.edited("      - uses: ./.github/actions/setup", concat("", ["      - uses: ./.github/actions/setup", mise_steps]))

missing := {
	"job build, step 2 runs mise without MISE_ENV=ci in its own, its job's or the workflow's env",
	"job build, step 3 runs mise without MISE_ENV=ci in its own, its job's or the workflow's env",
}

lines_with(old, new) := f.lines(replace(concat("\n", [l.Original | some l in with_mise]), old, new))

test_valid_workflow_passes if count(denied(f.lines(f.workflow))) == 0

test_mise_without_env_fails if denied(with_mise) == missing

test_mise_after_another_command_fails if {
	denied(lines_with("- run: mise install --locked", "- run: fsbench probe -- mise install --locked")) == missing
}

test_dev_profile_fails if {
	denied(lines_with("permissions:\n  contents: read\n", "permissions:\n  contents: read\nenv:\n  MISE_ENV: dev\n")) == missing
}

test_workflow_env_passes if {
	count(denied(lines_with("permissions:\n  contents: read\n", "permissions:\n  contents: read\nenv:\n  MISE_ENV: ci\n"))) == 0
}

test_job_env_with_more_profiles_passes if {
	count(denied(lines_with("    permissions:\n      contents: write\n", "    permissions:\n      contents: write\n    env:\n      MISE_ENV: ci,release\n"))) == 0
}

test_step_env_covers_only_its_step if {
	denied(lines_with("      - run: mise install --locked", "      - run: mise install --locked\n        env:\n          MISE_ENV: ci")) == {"job build, step 2 runs mise without MISE_ENV=ci in its own, its job's or the workflow's env"}
}

test_profile_named_like_ci_fails if {
	denied(lines_with("permissions:\n  contents: read\n", "permissions:\n  contents: read\nenv:\n  MISE_ENV: cix\n")) == missing
}

test_mise_paths_are_not_mise if {
	denied(lines_with("- run: mise install --locked", "- run: cat mise.lock mise-tasks/check.sh")) == {"job build, step 2 runs mise without MISE_ENV=ci in its own, its job's or the workflow's env"}
}

test_exception_applies if {
	ex := workflow_mise_env.exception with input as with_mise
		with data.conftest.file as f.file
		with data.workflow_exceptions.exceptions as {{"rule": "mise_env", "file": "ci.yml", "reason": "runs the dev profile's gitleaks"}}
	ex == {["mise_env"]}
}
