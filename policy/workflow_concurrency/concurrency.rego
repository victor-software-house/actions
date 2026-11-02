# One run per pull request or branch: a new push cancels the run it replaces.
package workflow_concurrency

import data.workflow_lib as lib
import rego.v1

key := "github.event.pull_request.number || github.ref_name"

deny_concurrency contains msg if {
	lib.on_pull_request
	# object.get, because a missing key would leave the comparison undefined.
	not contains(object.get(lib.workflow, ["concurrency", "group"], ""), key)
	msg := sprintf("concurrency.group must end in ${{ %s }}", [key])
}

deny_concurrency contains "concurrency must set cancel-in-progress: true" if {
	lib.on_pull_request
	object.get(lib.workflow, ["concurrency", "cancel-in-progress"], false) != true
}

exception contains ["concurrency"] if lib.excepted("concurrency")
