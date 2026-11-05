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
	value := object.get(job, ["with", "mise-env"], null)
	value != null
	not accepted(sprintf("%v", [value]))
	msg := sprintf("job %s passes mise-env %v to a reusable workflow; pass %s", [name, value, concat(" or ", profiles)])
}

deny_mise_env contains msg if some msg in lib.denied("mise_env", finding)

deny_mise_env contains lib.unloaded_message if lib.unloaded("mise_env")

warn_mise_env contains msg if some msg in lib.warned("mise_env", finding)
