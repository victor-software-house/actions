# One run per pull request or branch: a new push cancels the run it replaces.
package workflow_concurrency

import data.workflow_lib as lib
import rego.v1

# The accepted group endings are a parameter (defaults.yaml), which says why
# the draft suffix is among them.
endings := lib.param("concurrency", "endings")

group := trim_space(object.get(lib.workflow, ["concurrency", "group"], ""))

finding contains {"msg": msg} if {
	lib.on_pull_request

	# object.get, because a missing key would leave the comparison undefined.
	# The key comes last, or just before the draft suffix: anything else after
	# it, such as the commit SHA, gives every push its own group, and no push
	# cancels the run it replaces.
	not ends_in_key
	msg := sprintf("concurrency.group must end in one of: %s", [concat(", ", endings)])
}

ends_in_key if {
	some ending in endings
	endswith(group, ending)
}

finding contains {"msg": "concurrency must set cancel-in-progress: true"} if {
	lib.on_pull_request
	object.get(lib.workflow, ["concurrency", "cancel-in-progress"], false) != true
}

deny_concurrency contains msg if some msg in lib.denied("concurrency", finding)

deny_concurrency contains lib.unloaded_message if lib.unloaded("concurrency")

warn_concurrency contains msg if some msg in lib.warned("concurrency", finding)
