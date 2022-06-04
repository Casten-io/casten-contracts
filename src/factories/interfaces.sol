// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

interface NAVFeedFactoryLike {
    function newFeed() external returns (address);
}

interface TitleFabLike {
    function newTitle(string calldata, string calldata) external returns (address);
}

interface PileFactoryLike {
    function newPile() external returns (address);
}

interface ShelfFactoryLike {
    function newShelf(address, address, address, address) external returns (address);
}

interface ReserveFactoryLike {
    function newReserve(address) external returns (address);
}

interface AssessorFactoryLike {
    function newAssessor() external returns (address);
}

interface TrancheFactoryLike {
    function newTranche(address, address) external returns (address);
}

interface CoordinatorFactoryLike {
    function newCoordinator(uint) external returns (address);
}

interface OperatorFactoryLike {
    function newOperator(address) external returns (address);
}

interface MemberlistFactoryLike {
    function newMemberlist() external returns (address);
}

interface RestrictedTokenFactoryLike {
    function newRestrictedToken(string calldata, string calldata) external returns (address);
}

interface PoolAdminFactoryLike {
    function newPoolAdmin() external returns (address);
}

interface ClerkFactoryLike {
    function newClerk(address, address) external returns (address);
}

interface castenManagerFactoryLike {
    function newcastenManager(address, address, address,  address, address, address, address, address) external returns (address);
}

