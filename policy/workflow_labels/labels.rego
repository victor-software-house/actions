# Every runner label is a GitHub-hosted one or one .github/actionlint.yaml
# lists, so a typo fails here instead of queueing a job until it is
# cancelled. conftest reads actionlint.yaml with --data.
package workflow_labels

import data.workflow_lib as lib
import rego.v1

# GitHub's standard hosted runners. Larger runners bill even on public
# repositories, so they are not listed.
hosted := {
	"ubuntu-latest", "ubuntu-24.04", "ubuntu-22.04", "ubuntu-24.04-arm", "ubuntu-22.04-arm", "ubuntu-slim",
	"macos-latest", "macos-26", "macos-15", "macos-14",
	"windows-latest", "windows-2025", "windows-2022", "windows-11-arm",
}

# Empty when actionlint.yaml lists no label, as in a public repository.
listed := {label | some label in data["self-hosted-runner"].labels}

# A job's own runs-on, and the runner inputs it passes to a reusable workflow:
# `runner` or `*-runner`, one label or a JSON array of labels. An expression
# resolves at run time, so it is not checked here.
labels(job) := {label |
	some value in runner_values(job)
	some label in as_labels(value)
	not contains(label, "${{")
}

runner_values(job) := [job["runs-on"]] if "runs-on" in object.keys(job)

runner_values(job) := [value |
	some key, value in object.get(job, "with", {})
	regex.match(`^(.+-)?runner$`, key)
] if "uses" in object.keys(job)

as_labels(value) := [value] if {
	is_string(value)
	not startswith(value, "[")
}

as_labels(value) := json.unmarshal(value) if {
	is_string(value)
	startswith(value, "[")
}

as_labels(value) := value if is_array(value)

deny_labels contains msg if {
	some name, job in lib.jobs
	some label in labels(job)
	not label in hosted
	not label in listed
	msg := sprintf("job %s runs on %s, which is not a GitHub-hosted runner and .github/actionlint.yaml does not list", [name, label])
}

exception contains ["labels"] if lib.excepted("labels")
