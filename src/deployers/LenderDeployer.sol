// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import { ReserveFactoryLike, AssessorFactoryLike, TrancheFactoryLike, CoordinatorFactoryLike, OperatorFactoryLike, MemberlistFactoryLike, RestrictedTokenFactoryLike, PoolAdminFactoryLike, ClerkFactoryLike } from "./../factories/interfaces.sol";

import {FixedPoint}      from "./../fixed_point.sol";


interface DependLike {
    function depend(bytes32, address) external;
}

interface AuthLike {
    function rely(address) external;
    function deny(address) external;
}

interface MemberlistLike {
    function updateMember(address, uint) external;
}

interface FileLike {
    function file(bytes32 name, uint value) external;
}

interface PoolAdminLike {
    function rely(address) external;
}

contract LenderDeployer is FixedPoint {
    address public immutable root;
    address public immutable currency;
    address public immutable memberAdmin;

    // factory contracts
    TrancheFactoryLike          public immutable trancheFactory;
    ReserveFactoryLike          public immutable reserveFactory;
    AssessorFactoryLike         public immutable assessorFactory;
    CoordinatorFactoryLike      public immutable coordinatorFactory;
    OperatorFactoryLike         public immutable operatorFactory;
    MemberlistFactoryLike       public immutable memberlistFactory;
    RestrictedTokenFactoryLike  public immutable restrictedTokenFactory;
    PoolAdminFactoryLike        public immutable poolAdminFactory;

    // lender state variables
    Fixed27             public minSeniorRatio;
    Fixed27             public maxSeniorRatio;
    uint                public maxReserve;
    uint                public challengeTime;
    Fixed27             public seniorInterestRate;


    // contract addresses
    address             public adapterDeployer;
    address             public assessor;
    address             public poolAdmin;
    address             public seniorTranche;
    address             public juniorTranche;
    address             public seniorOperator;
    address             public juniorOperator;
    address             public reserve;
    address             public coordinator;

    address             public seniorToken;
    address             public juniorToken;

    // token names
    string              public seniorName;
    string              public seniorSymbol;
    string              public juniorName;
    string              public juniorSymbol;
    // restricted token member list
    address             public seniorMemberlist;
    address             public juniorMemberlist;

    address             public deployer;
    bool public wired;

    constructor(address root_, address currency_, address trancheFactory_, address memberlistFactory_, address restrictedtokenFab_, address reserveFactory_, address assessorFactory_, address coordinatorFactory_, address operatorFactory_, address poolAdminFactory_, address memberAdmin_, address adapterDeployer_) {
        deployer = msg.sender;
        root = root_;
        currency = currency_;
        memberAdmin = memberAdmin_;
        adapterDeployer = adapterDeployer_;

        trancheFactory = TrancheFactoryLike(trancheFactory_);
        memberlistFactory = MemberlistFactoryLike(memberlistFactory_);
        restrictedTokenFactory = RestrictedTokenFactoryLike(restrictedtokenFab_);
        reserveFactory = ReserveFactoryLike(reserveFactory_);
        assessorFactory = AssessorFactoryLike(assessorFactory_);
        poolAdminFactory = PoolAdminFactoryLike(poolAdminFactory_);
        coordinatorFactory = CoordinatorFactoryLike(coordinatorFactory_);
        operatorFactory = OperatorFactoryLike(operatorFactory_);
    }

    function init(uint minSeniorRatio_, uint maxSeniorRatio_, uint maxReserve_, uint challengeTime_, uint seniorInterestRate_, string memory seniorName_, string memory seniorSymbol_, string memory juniorName_, string memory juniorSymbol_) public {
        require(msg.sender == deployer);
        challengeTime = challengeTime_;
        minSeniorRatio = Fixed27(minSeniorRatio_);
        maxSeniorRatio = Fixed27(maxSeniorRatio_);
        maxReserve = maxReserve_;
        seniorInterestRate = Fixed27(seniorInterestRate_);

        // token names
        seniorName = seniorName_;
        seniorSymbol = seniorSymbol_;
        juniorName = juniorName_;
        juniorSymbol = juniorSymbol_;

        deployer = address(1);
    }

    function deployJunior() public {
        require(juniorTranche == address(0) && deployer == address(1));
        juniorToken = restrictedTokenFactory.newRestrictedToken(juniorSymbol, juniorName);
        juniorTranche = trancheFactory.newTranche(currency, juniorToken);
        juniorMemberlist = memberlistFactory.newMemberlist();
        juniorOperator = operatorFactory.newOperator(juniorTranche);
        AuthLike(juniorMemberlist).rely(root);
        AuthLike(juniorToken).rely(root);
        AuthLike(juniorToken).rely(juniorTranche);
        AuthLike(juniorOperator).rely(root);
        AuthLike(juniorTranche).rely(root);
    }

    function deploySenior() public {
        require(seniorTranche == address(0) && deployer == address(1));
        seniorToken = restrictedTokenFactory.newRestrictedToken(seniorSymbol, seniorName);
        seniorTranche = trancheFactory.newTranche(currency, seniorToken);
        seniorMemberlist = memberlistFactory.newMemberlist();
        seniorOperator = operatorFactory.newOperator(seniorTranche);
        AuthLike(seniorMemberlist).rely(root);
        AuthLike(seniorToken).rely(root);
        AuthLike(seniorToken).rely(seniorTranche);
        AuthLike(seniorOperator).rely(root);
        AuthLike(seniorTranche).rely(root);

        if (adapterDeployer != address(0)) {
            AuthLike(seniorTranche).rely(adapterDeployer);
            AuthLike(seniorMemberlist).rely(adapterDeployer);
        }
    }

    function deployReserve() public {
        require(reserve == address(0) && deployer == address(1));
        reserve = reserveFactory.newReserve(currency);
        AuthLike(reserve).rely(root);
        if (adapterDeployer != address(0)) AuthLike(reserve).rely(adapterDeployer);
    }

    function deployAssessor() public {
        require(assessor == address(0) && deployer == address(1));
        assessor = assessorFactory.newAssessor();
        AuthLike(assessor).rely(root);
        if (adapterDeployer != address(0)) AuthLike(assessor).rely(adapterDeployer);
    }

    function deployPoolAdmin() public {
        require(poolAdmin == address(0) && deployer == address(1));
        poolAdmin = poolAdminFactory.newPoolAdmin();
        PoolAdminLike(poolAdmin).rely(root);
        if (adapterDeployer != address(0)) PoolAdminLike(poolAdmin).rely(adapterDeployer);
    }

    function deployCoordinator() public {
        require(coordinator == address(0) && deployer == address(1));
        coordinator = coordinatorFactory.newCoordinator(challengeTime);
        AuthLike(coordinator).rely(root);
    }

    function deploy() public virtual {
        require(coordinator != address(0) && assessor != address(0) &&
                reserve != address(0) && seniorTranche != address(0));

        require(!wired, "lender contracts already wired"); // make sure lender contracts only wired once
        wired = true;

        // required depends
        // reserve
        AuthLike(reserve).rely(seniorTranche);
        AuthLike(reserve).rely(juniorTranche);
        AuthLike(reserve).rely(coordinator);
        AuthLike(reserve).rely(assessor);

        // tranches
        DependLike(seniorTranche).depend("reserve",reserve);
        DependLike(juniorTranche).depend("reserve",reserve);
        AuthLike(seniorTranche).rely(coordinator);
        AuthLike(juniorTranche).rely(coordinator);
        AuthLike(seniorTranche).rely(seniorOperator);
        AuthLike(juniorTranche).rely(juniorOperator);

        // coordinator implements epoch ticker interface
        DependLike(seniorTranche).depend("coordinator", coordinator);
        DependLike(juniorTranche).depend("coordinator", coordinator);

        //restricted token
        DependLike(seniorToken).depend("memberlist", seniorMemberlist);
        DependLike(juniorToken).depend("memberlist", juniorMemberlist);

        //allow casten contracts to hold SEN/JUN tokens
        MemberlistLike(juniorMemberlist).updateMember(juniorTranche, type(uint256).max);
        MemberlistLike(seniorMemberlist).updateMember(seniorTranche, type(uint256).max);

        // operator
        DependLike(seniorOperator).depend("tranche", seniorTranche);
        DependLike(juniorOperator).depend("tranche", juniorTranche);
        DependLike(seniorOperator).depend("token", seniorToken);
        DependLike(juniorOperator).depend("token", juniorToken);

        // coordinator
        DependLike(coordinator).depend("seniorTranche", seniorTranche);
        DependLike(coordinator).depend("juniorTranche", juniorTranche);
        DependLike(coordinator).depend("assessor", assessor);

        AuthLike(coordinator).rely(poolAdmin);

        // assessor
        DependLike(assessor).depend("seniorTranche", seniorTranche);
        DependLike(assessor).depend("juniorTranche", juniorTranche);
        DependLike(assessor).depend("reserve", reserve);

        AuthLike(assessor).rely(coordinator);
        AuthLike(assessor).rely(reserve);
        AuthLike(assessor).rely(poolAdmin);

        // poolAdmin
        DependLike(poolAdmin).depend("assessor", assessor);
        DependLike(poolAdmin).depend("juniorMemberlist", juniorMemberlist);
        DependLike(poolAdmin).depend("seniorMemberlist", seniorMemberlist);
        DependLike(poolAdmin).depend("coordinator", coordinator);

        AuthLike(juniorMemberlist).rely(poolAdmin);
        AuthLike(seniorMemberlist).rely(poolAdmin);

        if (memberAdmin != address(0)) AuthLike(juniorMemberlist).rely(memberAdmin);
        if (memberAdmin != address(0)) AuthLike(seniorMemberlist).rely(memberAdmin);

        FileLike(assessor).file("seniorInterestRate", seniorInterestRate.value);
        FileLike(assessor).file("maxReserve", maxReserve);
        FileLike(assessor).file("maxSeniorRatio", maxSeniorRatio.value);
        FileLike(assessor).file("minSeniorRatio", minSeniorRatio.value);
    }
}
