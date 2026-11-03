# The workflow token reads only; a job that writes grants that scope itself.
package workflow_permissions

import data.workflow_lib as lib
import rego.v1

deny_permissions contains "top-level permissions must map each scope to read or none" if {
	# object.get, because a missing key outside `not` would skip the rule.
	not is_object(object.get(lib.workflow, "permissions", null))
}

deny_permissions contains msg if {
	some scope, level in object.get(lib.workflow, "permissions", {})
	not level in {"read", "none"}
	msg := sprintf("top-level permission %s is %s; grant write on the job that needs it", [scope, level])
}

deny_permissions contains msg if {
	some name, job in lib.jobs
	"permissions" in object.keys(job)
	not is_object(job.permissions)
	msg := sprintf("job %s must map each permission scope, not %v", [name, job.permissions])
}

exception contains ["permissions"] if lib.excepted("permissions")
