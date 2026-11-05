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

text_with_mise := replace(f.workflow, "      - uses: ./.github/actions/setup", concat("", ["      - uses: ./.github/actions/setup", mise_steps]))

with_mise := f.edited("      - uses: ./.github/actions/setup", concat("", ["      - uses: ./.github/actions/setup", mise_steps]))

missing := {
	"job build, step 2 runs mise without MISE_ENV=ci in its own, its job's or the workflow's env",
	"job build, step 3 runs mise without MISE_ENV=ci in its own, its job's or the workflow's env",
}

lines_with(old, new) := f.lines(replace(concat("\n", [l.Original | some l in with_mise]), old, new))

test_valid_workflow_passes if count(denied(f.lines(f.workflow))) == 0

test_mise_without_env_fails if denied(with_mise) == missing

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

# GitHub takes the nearest env: a step's dev beats the workflow's ci.
test_step_profile_overrides_the_workflow if {
	workflow_ci := concat("\n", [l.Original | some l in lines_with("permissions:\n  contents: read\n", "permissions:\n  contents: read\nenv:\n  MISE_ENV: ci\n")])
	denied(f.lines(replace(workflow_ci, "      - run: mise install --locked", "      - run: mise install --locked\n        env:\n          MISE_ENV: dev"))) == {"job build, step 3 runs mise without MISE_ENV=ci in its own, its job's or the workflow's env"}
}

# Each run replaces the build job's `mise install --locked` step (step 3);
# the mise-action step (step 2) still fails beside it.
step_2 := "job build, step 2 runs mise without MISE_ENV=ci in its own, its job's or the workflow's env"

calls := [
	"fsbench probe -label x -- mise install --locked",
	`bash -c "mise install"`,
	`bash -lc "mise install"`,
	"~/.local/bin/mise install",
	"./mise install",
	"/usr/local/mise install",
	"$HOME/tools/mise install",
	"cd tools && mise run test",
	"cd tools && mise",
	"MISE_YES=1 mise install",
	"timeout 300 mise run test",
	"sudo -E mise install",
	"nice -n 10 mise run test",
	"env -i mise install",
	"if mise doctor; then echo ok; fi",
	"! mise doctor",
	"echo start; mise verify",
	"echo $(mise which go)",
	"echo `mise which go`",
	# Found on purpose: the rule errs toward finding.
	"rm -rf ~/.cache/mise",
	`grep -c "mise" mise.lock`,
	"wc -c 'mise'",
]

not_calls := [
	"cat mise.lock mise.toml mise-tasks/check.sh",
	"fsbench fetch -lock mise.lock",
	"ls .mise/",
	"echo \"$MISE_ENV\" mise_env",
]

test_each_call_fails if {
	every run in calls {
		denied(lines_with("- run: mise install --locked", sprintf("- run: %s", [json.marshal(run)]))) == missing
	}
}

test_multi_line_call_fails if {
	denied(lines_with("- run: mise install --locked", "- run: |\n          echo start\n          mise install --locked")) == missing
}

test_each_non_call_passes if {
	every run in not_calls {
		denied(lines_with("- run: mise install --locked", sprintf("- run: %s", [json.marshal(run)]))) == {step_2}
	}
}

test_expression_is_not_checked if {
	count(denied(lines_with("permissions:\n  contents: read\n", "permissions:\n  contents: read\nenv:\n  MISE_ENV: ${{ inputs.mise-env }}\n"))) == 0
}

# The fixture's verify job calls a reusable workflow.
caller(env) := f.edited("    with:\n      light-runner:", sprintf("    with:\n      mise-env: %s\n      light-runner:", [env]))

test_caller_passing_dev_fails if {
	denied(caller("dev,release")) == {"job verify passes mise-env dev,release to a reusable workflow; pass ci"}
}

test_caller_passing_ci_passes if {
	count(denied(caller("ci,release"))) == 0
}

test_caller_passing_nothing_fails if {
	count(denied(f.edited("    with:\n      light-runner:", "    with:\n      mise-env:\n      light-runner:"))) == 1
}

# The fixture with the workflow's env set to ci and the mise install step
# replaced by run, so only the run script's own overrides can fail.
ci_run(run) := lines_with("- run: mise install --locked", sprintf("- run: %s", [json.marshal(run)]))

ci_workflow(run) := f.lines(replace(concat("\n", [l.Original | some l in ci_run(run)]), "permissions:\n  contents: read\n", "permissions:\n  contents: read\nenv:\n  MISE_ENV: ci\n"))

test_inline_profile_fails if {
	denied(ci_workflow("MISE_ENV=dev mise install")) == {"job build, step 3 sets MISE_ENV=dev in its run script"}
}

test_github_env_profile_fails if {
	denied(ci_workflow(`echo MISE_ENV=dev >> "$GITHUB_ENV"`)) == {"job build, step 3 sets MISE_ENV=dev in its run script"}
}

test_inline_ci_profile_passes if count(denied(ci_workflow("MISE_ENV=ci,release mise install"))) == 0

test_longer_variable_name_passes if count(denied(ci_workflow("MY_MISE_ENV=dev mise install"))) == 0

test_env_flag_fails if {
	every run in ["mise --env dev install", "mise -E dev install", "mise -C sub -E dev install", "mise -q --env=dev run x", "mise -qE dev install", "mise -yE dev install", "~/.local/bin/mise -E dev install", "$HOME/.local/share/mise/bin/mise --env dev install", `bash -c "mise -E dev install"`] {
		denied(ci_workflow(run)) == {"job build, step 3 runs mise --env dev"}
	}
}

test_env_flag_of_another_program_passes if {
	every run in ["mise exec -- grep -E foo x", "mise run deploy --env prod", "mise --env ci install"] {
		count(denied(ci_workflow(run))) == 0
	}
}

test_unset_fails if {
	every run in ["unset MISE_ENV", "env -u MISE_ENV mise install", "env --unset=MISE_ENV mise install"] {
		denied(ci_workflow(run)) == {"job build, step 3 unsets MISE_ENV in its run script"}
	}
}

test_unset_other_variable_passes if count(denied(ci_workflow("unset OTHER; mise install"))) == 0
