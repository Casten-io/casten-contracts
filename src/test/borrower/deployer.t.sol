// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "../../lib/ds-test/src/test.sol";
import { Title } from "../../lib/casten-title/src/title.sol";
import { TitleFab } from "../../factories/title.sol";
import { PileFactory } from "../../factories/pile.sol";
import { ShelfFactory} from "../../factories/shelf.sol";
import { TestNAVFeedFab } from "../borrower/factories/navfeed.tests.sol";

import "../../deployers/BorrowerDeployer.sol";
import { SimpleToken } from "../../test/simple/token.sol";

contract DeployerTest is DSTest {
    Title nft;
    SimpleToken dai;
    TitleFab titlefab;
    ShelfFactory shelfFactory;
    PileFactory pileFactory;
    TestNAVFeedFab feedFab;
    Title title;

    function setUp() public {
        nft = new Title("SimpleNFT", "NFT");
        dai = new SimpleToken("DDAI", "Dummy Dai");
        titlefab = new TitleFab();
        shelfFactory = new ShelfFactory();
        pileFactory = new PileFactory();
        feedFab = new TestNAVFeedFab();
   }

    function testBorrowerDeploy() public logs_gas {
        uint discountRate = uint(1000000342100000000000000000);
        BorrowerDeployer deployer = new BorrowerDeployer(address(0), address(titlefab), address(shelfFactory), address(pileFactory), address(feedFab), address(dai), "Test", "TEST", discountRate);

        deployer.deployTitle();
        deployer.deployPile();
        deployer.deployFeed();
        deployer.deployShelf();
        deployer.deploy();
    }
}
