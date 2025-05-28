// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.30;

import {SingleAuth} from "src/Auth/SingleAuth.sol";
import {Proxy1967} from "src/ERC1967/Proxy1967.sol";

// Proxy-Implementation Pair Structure
struct ProxyPair {
    // ERC1967 Proxy
    Proxy1967 proxy;
    // Implementation Address
    address Impl;
}

// Deployment Status
enum Status {
    Queued,
    Cancelled,
    Deployed,
    RolledBack
}

// Deployment Structure
struct Deployment {
    // Deployment Status
    Status status;
    // Timestamp at which deployment may execute.
    uint64 readyAt;
    // Salts for create2 proxy deployments.
    bytes32[] proxySalts;
    // Proxy implementation pairs.
    ProxyPair[] proxyImpls;
    // Proxy state diffs (set at deployment).
    ProxyPair[] proxyImplsDiffs;
}

/// @title Proxy Monitor
/// @author jtriley2p
/// @notice Deploys and upgrades proxies with a timelock-able queue. Deployments may be queued,
///         cancelled, executed, and/or rolled back.
/// @dev Deployments may only be cancelled if they are queued, but not deployed.
/// @dev Deployments may only be deployed if they are queued and the timelock as passed.
/// @dev Deployments may only be rolled back if they are deployed.
contract ProxyMon is SingleAuth {
    /// @notice Logged on status update.
    /// @param index Deployment index.
    /// @param status New deployment status.
    event StatusUpdate(uint256 indexed index, Status status);

    /// @notice Most recent deployment index.
    uint256 deploymentIndex;

    /// @notice Historical deployments array; facilitates rollbacks.
    Deployment[] public deployments;

    /// @notice Queues a new deployment. There MUST NOT be any currently queued deployments.
    /// @param timelock Seconds before deployment can be executed.
    /// @param proxySalts Salts for create2 proxy deployments.
    /// @param proxyImpls Pairs of addresses representing the proxy and respective implementation.
    function queue(uint64 timelock, bytes32[] calldata proxySalts, ProxyPair[] calldata proxyImpls) public {
        require(msg.sender == admin);

        require(deploymentIndex == deployments.length - 1);

        deployments.push(
            Deployment(
                Status.Queued, uint64(block.timestamp + timelock), proxySalts, proxyImpls, new ProxyPair[](0)
            )
        );

        emit StatusUpdate(deployments.length - 1, Status.Queued);
    }

    /// @notice Cancels a deployment. The most recent deployment MUST have the queue status.
    function cancel() public {
        require(msg.sender == admin);

        uint256 index = deploymentIndex;
        Deployment storage deployment = deployments[index];

        require(deployment.status == Status.Queued);

        deployment.status = Status.Cancelled;
        deploymentIndex = index + 1;

        emit StatusUpdate(index, Status.Cancelled);
    }

    /// @notice Executes a deployment.
    /// @notice Deployment must be queued and timelock must have passed.
    /// @notice Iterates proxy deployments (via proxySalts), iterates proxy upgrades, then updates
    ///         deployment status and increments the deployment index.
    /// @dev `proxyImplDiffs` stores the implementation address before upgrading for rollbacks.
    function deploy() public {
        require(msg.sender == admin);

        uint256 index = deploymentIndex;
        Deployment storage deployment = deployments[index];

        require(deployment.status == Status.Queued);
        require(deployment.readyAt <= block.timestamp);

        for (uint256 i; i < deployment.proxySalts.length; i++) {
            new Proxy1967{salt: deployment.proxySalts[i]}();
        }

        for (uint256 i; i < deployment.proxyImpls.length; i++) {
            Proxy1967 proxy = deployment.proxyImpls[i].proxy;
            address Impl = deployment.proxyImpls[i].Impl;
            address lastImpl = proxy.implementation();

            proxy.upgrade(Impl);

            deployment.proxyImplsDiffs[i] = ProxyPair(proxy, lastImpl);
        }

        deployment.status = Status.Deployed;
        deploymentIndex = index + 1;

        emit StatusUpdate(index, Status.Deployed);
    }

    /// @notice Rolls back a deployment.
    /// @notice If deployment is most recent, proxies are all upgraded to zero address.
    /// @notice Finds last successful deployment, then iterates `proxyImplsDiffs` to upgrade to
    ///         previous deployment.
    function rollBack() public {
        require(msg.sender == admin);

        uint256 index = deploymentIndex;
        Deployment storage deployment = deployments[index];

        require(index == deployments.length - 1);
        require(deployment.status == Status.Deployed);

        uint256 lastDeployedIndex = index - 1;

        while (true) {
            if (lastDeployedIndex == 0 || deployments[lastDeployedIndex].status == Status.Deployed) {
                break;
            }

            lastDeployedIndex -= 1;
        }

        Deployment storage lastDeployment = deployments[lastDeployedIndex];

        if (lastDeployedIndex == 0) {
            for (uint256 i; i < lastDeployment.proxyImpls.length; i++) {
                lastDeployment.proxyImpls[i].proxy.upgrade(address(0x00));
            }
        } else {
            for (uint256 i; i < lastDeployment.proxyImplsDiffs.length; i++) {
                Proxy1967 proxy = lastDeployment.proxyImplsDiffs[i].proxy;
                address lastImpl = lastDeployment.proxyImplsDiffs[i].Impl;

                proxy.upgrade(lastImpl);
            }
        }

        emit StatusUpdate(index, Status.RolledBack);
    }
}
