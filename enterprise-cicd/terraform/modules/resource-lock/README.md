# Resource Lock module

Applies an Azure Management Lock to a governed resource. Production catalog requests use `CanNotDelete` by default so normal updates remain possible while accidental deletion requires an explicit lock-removal change.
