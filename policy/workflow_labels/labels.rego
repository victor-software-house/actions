# Every runner label is a GitHub-hosted one or one .github/actionlint.yaml
# lists, so a typo fails here instead of queueing a job until it is
# cancelled. conftest reads actionlint.yaml with --data.
package workflow_labels

import data.workflow_lib as lib
import rego.v1

# The hosted runners and the other accepted labels are parameters
# (defaults.yaml); actionlint.yaml's labels are accepted too, and are empty
# when it lists none, as in a public repository.
accepted := {label | some label in array.concat(lib.param("labels", "hosted"), lib.param("labels", "allowed"))}

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

# runs-on: {group: …, labels: …}; a group alone names no label to check.
as_labels(value) := [value.labels] if is_string(value.labels)

as_labels(value) := value.labels if is_array(value.labels)

finding contains {"msg": msg, "job": name} if {
	some name, job in lib.jobs
	some label in labels(job)
	not label in accepted
	not label in listed
	regex.match(lib.param("labels", "superseded"), label)
	msg := sprintf("job %s runs on %s; GitHub-hosted Ubuntu runners must be ubuntu-26.04 or ubuntu-26.04-arm", [name, label])
}

finding contains {"msg": msg, "job": name} if {
	some name, job in lib.jobs
	some label in labels(job)
	not label in accepted
	not label in listed
	not regex.match(lib.param("labels", "superseded"), label)
	msg := sprintf("job %s runs on %s, which is not a GitHub-hosted runner and .github/actionlint.yaml does not list", [name, label])
}

deny_labels contains msg if some msg in lib.denied("labels", finding)

deny_labels contains lib.unloaded_message if lib.unloaded("labels")

warn_labels contains msg if some msg in lib.warned("labels", finding)
