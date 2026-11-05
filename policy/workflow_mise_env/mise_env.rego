# A workflow that runs mise loads the ci profile. A repository's .miserc.toml
# makes dev the default profile for local work, which adds mise.dev.toml's
# local-only tools (the git hooks and their scanners); a runner without
# MISE_ENV=ci would install them on every job.
package workflow_mise_env

import data.workflow_lib as lib
import rego.v1

runs_mise(step) if startswith(object.get(step, "uses", ""), "jdx/mise-action@")

# mise run as a command, by name or by any path (./mise, ~/.local/bin/mise),
# where a shell command starts: the start of a line, after a separator, an
# opening parenthesis or $(, inside bash -c "…", or after a wrapper's --,
# past any VAR=value assignments and the wrappers env, time, sudo, nice, nohup,
# exec, command, xargs and timeout <limit>. mise as an argument, as in
# ls ~/.local/bin/mise or rm -rf ~/.cache/mise, is not a call, and neither are
# mise.lock and mise-tasks/.
runs_mise(step) if regex.match(command, object.get(step, "run", ""))

command := `(^|\n|[;&|(]|\$\(|-c\s+["']|\s--\s)\s*(\w+=\S*\s+)*((env|time|sudo|nice|nohup|exec|command|xargs|timeout\s+\S+)\s+)*(\S*/)?mise(\s|["')]|$)`

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
