# Proxy Controller

> WIP

Proxy Controller manages deployments and upgrades of proxy contracts. A deployment facilitates an
arbitrary number of proxy deployments as well as proxy-implementation pairs to set. A deployment may
be queued, cancelled, executed, and rolled back.

The rollback feature retains additional state variables, but enables a seamless rollback in the
event a rollback causes unexpected issues.

There are also minimal implementations for ERC1967 Proxy, BeaconProxy, and Beacon contracts and some
authorization modules including a multi-step, single admin contract and a configurable weighted
multiple signature contract.
