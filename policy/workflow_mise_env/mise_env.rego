# A workflow that runs mise loads the ci profile. A repository's .miserc.toml
# makes dev the default profile for local work, which adds mise.dev.toml's
# local-only tools (the git hooks and their scanners); a runner without
# MISE_ENV=ci would install them on every job.
package workflow_mise_env

import data.workflow_lib as lib
import rego.v1

runs_mise(step) if startswith(object.get(step, "uses", ""), "jdx/mise-action@")

# Any step whose script names the word mise runs it, wherever it stands: after
# a shell keyword, a wrapper and its flags, a quote, a backtick or a path. A
# shell script cannot be parsed reliably here, so the rule errs toward finding:
# a step that only names a mise folder, such as rm -rf ~/.cache/mise, is found
# too, and MISE_ENV: ci costs it nothing. mise.lock, mise.toml, mise-tasks/,
# .mise/, mise_env and MISE_ENV are other words.
runs_mise(step) if regex.match(`(^|[^\w.-])mise($|[^\w.-])`, object.get(step, "run", ""))

# The accepted profiles (defaults.yaml): each alone, or first among several,
# such as ci,release.
profiles := lib.param("mise_env", "profiles")

accepted(value) if value in profiles

accepted(value) if {
	some profile in profiles
	startswith(value, concat("", [profile, ","]))
}

# An expression resolves at run time, such as a reusable workflow's
# MISE_ENV: ${{ inputs.mise-env }}, so it is not checked here, as the labels
# rule leaves expressions alone.
accepted(value) if contains(value, "${{")

# A workflow the exempt parameter names may also set the values it lists.
accepted(value) if {
	some entry in lib.param("mise_env", "exempt")
	entry.file == data.conftest.file.name
	value in entry.profiles
}

# GitHub resolves an env key from the step, then the job, then the workflow,
# so only the nearest MISE_ENV counts: a step that sets dev under a workflow
# that sets ci loads dev.
effective(job, step) := object.get(step, ["env", "MISE_ENV"], object.get(job, ["env", "MISE_ENV"], object.get(lib.workflow, ["env", "MISE_ENV"], "")))

finding contains {"msg": msg, "job": name, "step": step} if {
	some name, job in lib.jobs
	some i, step in object.get(job, "steps", [])
	runs_mise(step)
	not accepted(effective(job, step))
	msg := sprintf("job %s, step %d runs mise without MISE_ENV=%s in its own, its job's or the workflow's env", [name, i + 1, concat(" or ", profiles)])
}

# A job that calls a reusable workflow and passes it a mise-env input, as
# verctl's release workflow takes, hands that workflow its MISE_ENV.
finding contains {"msg": msg, "job": name} if {
	some name, job in lib.jobs
	"uses" in object.keys(job)

	# A key with no value passes an empty input, which falls back to dev too.
	"mise-env" in object.keys(object.get(job, "with", {}))
	value := object.get(job, ["with", "mise-env"], "")
	not accepted(sprintf("%v", [value]))
	msg := sprintf("job %s passes mise-env %v to a reusable workflow; pass %s", [name, value, concat(" or ", profiles)])
}

deny_mise_env contains msg if some msg in lib.denied("mise_env", finding)

deny_mise_env contains lib.unloaded_message if lib.unloaded("mise_env")

warn_mise_env contains msg if some msg in lib.warned("mise_env", finding)

# A run script overrides every env: map above it when it assigns MISE_ENV
# inline or writes it to $GITHUB_ENV, passes mise -E or --env, or unsets
# MISE_ENV, which falls back to .miserc.toml's dev. OPA's RE2 has no
# lookahead, so each value is matched and then checked.
inline_values(run) := [m[2] | some m in regex.find_all_string_submatch_n(`(^|[^A-Za-z0-9_])MISE_ENV=["']?([^\s"';&|]*)`, run, -1)]

# mise reads -E and --env only before its subcommand, among its own flags
# (each a -flag, with or without a value; -E may also end a group such as
# -qE), so
# a -E after exec, run or a task name belongs to another program and is not
# matched. mise itself may be named by a path, as runs_mise reads it.
flag_values(run) := [m[2] | some m in regex.find_all_string_submatch_n(`(^|[^\w.-])mise(?:\s+-[^\s=-][^\s=]*(?:[\s=][^\s;&|-][^\s;&|]*)?|\s+--[^\s=e][^\s=]*(?:[\s=][^\s;&|-][^\s;&|]*)?)*\s+(?:-[A-Za-z]*E[\s=]*|--env[\s=]+)["']?([^\s"';&|]*)`, run, -1)]

unsets(run) if regex.match(`(^|[\s;&|(])unset\s(?:[^;&|\n]*\s)?MISE_ENV([\s;&|]|$)|(^|\s)(?:-u\s*|--unset[\s=]+)MISE_ENV([\s;&|]|$)`, run)

finding contains {"msg": msg, "job": name, "step": step} if {
	some name, job in lib.jobs
	some i, step in object.get(job, "steps", [])
	some value in inline_values(object.get(step, "run", ""))
	not accepted(value)
	msg := sprintf("job %s, step %d sets MISE_ENV=%s in its run script", [name, i + 1, value])
}

finding contains {"msg": msg, "job": name, "step": step} if {
	some name, job in lib.jobs
	some i, step in object.get(job, "steps", [])
	some value in flag_values(object.get(step, "run", ""))
	not accepted(value)
	msg := sprintf("job %s, step %d runs mise --env %s", [name, i + 1, value])
}

finding contains {"msg": msg, "job": name, "step": step} if {
	some name, job in lib.jobs
	some i, step in object.get(job, "steps", [])
	unsets(object.get(step, "run", ""))
	msg := sprintf("job %s, step %d unsets MISE_ENV in its run script", [name, i + 1])
}
