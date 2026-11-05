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

# ci alone, or ci first among several profiles, such as ci,release.
ci_profile(value) if value == "ci"

ci_profile(value) if startswith(value, "ci,")

# GitHub resolves an env key from the step, then the job, then the workflow,
# so only the nearest MISE_ENV counts: a step that sets dev under a workflow
# that sets ci loads dev.
effective(job, step) := object.get(step, ["env", "MISE_ENV"], object.get(job, ["env", "MISE_ENV"], object.get(lib.workflow, ["env", "MISE_ENV"], "")))

loads_ci(job, step) if ci_profile(effective(job, step))

deny_mise_env contains msg if {
	some name, job in lib.jobs
	some i, step in object.get(job, "steps", [])
	runs_mise(step)
	not loads_ci(job, step)
	msg := sprintf("job %s, step %d runs mise without MISE_ENV=ci in its own, its job's or the workflow's env", [name, i + 1])
}

exception contains ["mise_env"] if lib.excepted("mise_env")
