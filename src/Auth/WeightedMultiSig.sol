// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.30;

// ERC-2098 Authorization Data Structure.
struct Authorization {
    // "R" component of ECDSA signature.
    bytes32 r;
    // "S" and "Y-parity" ("V") of ECDSA signature.
    bytes32 vs;
}

/// @title Weighted Multiple Signature Contract
/// @author jtriley2p
/// @notice Manages authorization "weight" associated with each address. This creates a flexible
///         multi-signature scheme where a single address authorization, multiple equally-weighted
///         address authorization, or multiple differently-weighted address authorization is
///         possible.
/// @dev 1-of-1 Auth: admin weight is 1 and threshold is 1.
/// @dev M-of-N Auth: admin weight of each is 1 and threshold is N.
/// @dev M-of-N Weighted Auth: admin weight of each is variable and threshold is N.
contract WeightedMultiSig {
    /// @notice Logged when weight is set.
    /// @param admin Address whose weight is set.
    /// @param weight Weight assigned to admin.
    event WeightSet(address indexed admin, uint256 weight);

    /// @notice Logged when threshold is set.
    /// @param threshold New threshold for authorization.
    event ThresholdSet(uint256 threshold);

    /// @notice Maps addresses to authorization weights.
    mapping(address => uint256) public weights;

    /// @notice Threshold for authorization weight.
    uint256 authorizationThreshold;

    /// @notice Collective nonce for signature uniqueness.
    uint256 collectiveNonce;

    /// @notice Authorizes an action. Reverts on failure.
    /// @param data Arbitrary data to authorize.
    /// @param auths Signatures to validate.
    /// @dev Collective nonce is managed here as a means of separation of concerns.
    function authorize(bytes memory data, Authorization[] calldata auths) public {
        bytes32 hash = keccak256(abi.encodePacked(data, collectiveNonce));

        uint256 weight;

        for (uint256 i; i < auths.length; i++) {
            uint8 v = uint8(uint256(auths[i].vs >> 255)) + 27;

            bytes32 s = auths[i].vs << 255 >> 255;

            address signer = ecrecover(hash, v, auths[i].r, s);

            weight += weights[signer];
        }

        require(weight >= authorizationThreshold);

        collectiveNonce += 1;
    }

    /// @notice Sets authorization weight for an account.
    /// @param admin Address to which to set the weight.
    /// @param weight Weight set for account.
    /// @param auths Signatures of other admins.
    function setWeight(address admin, uint256 weight, Authorization[] calldata auths) public {
        authorize(abi.encodePacked(msg.sig, admin, weight), auths);

        weights[admin] = weight;

        emit WeightSet(admin, weight);
    }

    /// @notice Sets weight threshold for authorization.
    /// @param threshold Weight threshold to set.
    /// @param auths Signatures of other admins.
    function setAuthThreshold(uint256 threshold, Authorization[] calldata auths) public {
        authorize(abi.encodePacked(msg.sig, threshold), auths);

        authorizationThreshold = threshold;

        emit ThresholdSet(threshold);
    }
}
