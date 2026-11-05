# A workflow that runs mise loads the ci profile. A repository's .miserc.toml
# makes dev the default profile for local work, which adds mise.dev.toml's
# local-only tools (the git hooks and their scanners); a runner without
# MISE_ENV=ci would install them on every job.
package workflow_mise_env

import data.workflow_lib as lib
import rego.v1

runs_mise(step) if startswith(object.get(step, "uses", ""), "jdx/mise-action@")

# mise as a command word: at the start, or after a space, a separator or an
# opening parenthesis. mise.lock and mise-tasks/ are not commands.
runs_mise(step) if regex.match(`(^|[\s;&|(])mise\s`, object.get(step, "run", ""))

# ci alone, or ci first among several profiles, such as ci,release.
ci_profile(env) if env.MISE_ENV == "ci"

ci_profile(env) if startswith(env.MISE_ENV, "ci,")

# The step's own env, its job's, or the workflow's.
loads_ci(job, step) if ci_profile(object.get(step, "env", {}))

loads_ci(job, step) if ci_profile(object.get(job, "env", {}))

loads_ci(job, step) if ci_profile(object.get(lib.workflow, "env", {}))

deny_mise_env contains msg if {
	some name, job in lib.jobs
	some i, step in object.get(job, "steps", [])
	runs_mise(step)
	not loads_ci(job, step)
	msg := sprintf("job %s, step %d runs mise without MISE_ENV=ci in its own, its job's or the workflow's env", [name, i + 1])
}

exception contains ["mise_env"] if lib.excepted("mise_env")
