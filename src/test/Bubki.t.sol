// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.11;

/// Unit tests largely copied from solmate v6, with a few modifications for our mint function

import {DSTestPlus} from "./utils/DSTestPlus.sol";
//import {DSInvariantTest} from "./utils/DSInvariantTest.sol";

import {ERC721User} from "./utils/users/ERC721User.sol";

import {Bubki, ERC721TokenReceiver} from "../Bubki.sol";

contract ERC721Recipient is ERC721TokenReceiver {
    address public operator;
    address public from;
    uint256 public id;
    bytes public data;

    function onERC721Received(
        address _operator,
        address _from,
        uint256 _id,
        bytes calldata _data
    ) public virtual override returns (bytes4) {
        operator = _operator;
        from = _from;
        id = _id;
        data = _data;

        return ERC721TokenReceiver.onERC721Received.selector;
    }
}

contract RevertingERC721Recipient is ERC721TokenReceiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) public virtual override returns (bytes4) {
        revert(string(abi.encodePacked(ERC721TokenReceiver.onERC721Received.selector)));
    }
}

contract WrongReturnDataERC721Recipient is ERC721TokenReceiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) public virtual override returns (bytes4) {
        return 0xCAFEBEEF;
    }
}

contract NonERC721Recipient {}

interface Vm {
    function prank(address from) external;
    function startPrank(address from) external;
    function stopPrank() external;
    function deal(address who, uint256 amount) external;
    function expectRevert(bytes calldata expectedError) external;
}

contract BubkiTest is DSTestPlus {
    Bubki token;
    Vm vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    uint costPublic = 0.05 ether;

    function setUp() public {
        vm.deal(address(0xB33F), 1 ether);
        token = new Bubki();
        token.flipSaleState();
    }

    function testMetadata() public {
        assertEq(token.name(), "Bubki for Ukraine");
        assertEq(token.symbol(), "Bubki");
    }

    function testTokenURI() public {
        token.updateBaseURI('ipfs://blah/');
        vm.prank(address(0xB33F));
        token.mint{value: 5*costPublic}(5);
        assertEq(token.ownerOf(0), address(0xB33F));
        assertEq(token.ownerOf(1), address(0xB33F));
        assertEq(token.ownerOf(2), address(0xB33F));
        assertEq(token.ownerOf(3), address(0xB33F));
        assertEq(token.ownerOf(4), address(0xB33F));
        assertEq(token.ownerOf(5), address(0));
        assertEq(token.tokenURI(0), "ipfs://blah/0.json");
        assertEq(token.tokenURI(1), "ipfs://blah/1.json");
        assertEq(token.tokenURI(2), "ipfs://blah/2.json");
        assertEq(token.tokenURI(3), "ipfs://blah/3.json");
        assertEq(token.tokenURI(4), "ipfs://blah/4.json");
        vm.expectRevert("");
        token.tokenURI(5);
    }

    // written this way in case the from addr doesnt have money
    function mintOneToFrom(address from) public {
        vm.prank(address(0xB33F));
        token.mint{value: costPublic}(1);
        vm.prank(address(0xB33F));
        token.transferFrom(address(0xB33F), from, 0);
    }

    function testMintCorrectness() public {
        mintOneToFrom(address(0xDEAD));

        assertEq(token.balanceOf(address(0xDEAD)), 1);
        assertEq(token.ownerOf(0), address(0xDEAD));

        vm.prank(address(0xB33F));
        token.mint{value: (5*costPublic)}(5);
        assertEq(token.balanceOf(address(0xB33F)), 5);
        assertEq(token.totalSupply(), 6);
        assertEq(token.ownerOf(1), address(0xB33F));
        assertEq(token.ownerOf(2), address(0xB33F));
        assertEq(token.ownerOf(3), address(0xB33F));
        assertEq(token.ownerOf(4), address(0xB33F));
        assertEq(token.ownerOf(5), address(0xB33F));
    }

    function testApprove() public {
        mintOneToFrom(address(this));

        token.approve(address(0xBEEF), 0);

        assertEq(token.getApproved(0), address(0xBEEF));
    }

    function testApproveAll() public {
        token.setApprovalForAll(address(0xBEEF), true);

        assertTrue(token.isApprovedForAll(address(this), address(0xBEEF)));
    }

    function testTransferFrom() public {
        ERC721User from = ERC721User(address(token));

        mintOneToFrom(address(from));

        vm.prank(address(from));
        from.approve(address(this), 0);

        token.transferFrom(address(from), address(0xBEEF), 0);

        assertEq(token.getApproved(0), address(0));
        assertEq(token.ownerOf(0), address(0xBEEF));
        assertEq(token.balanceOf(address(0xBEEF)), 1);
        assertEq(token.balanceOf(address(from)), 0);
        assertEq(token.balanceOf(address(this)), 0);
    }

    function testTransferFromSelf() public {
        mintOneToFrom(address(this));

        token.transferFrom(address(this), address(0xBEEF), 0);

        assertEq(token.getApproved(0), address(0));
        assertEq(token.ownerOf(0), address(0xBEEF));
        assertEq(token.balanceOf(address(0xBEEF)), 1);
        assertEq(token.balanceOf(address(this)), 0);
    }

    function testTransferFromApproveAll() public {
        ERC721User from = ERC721User(address(token));

        mintOneToFrom(address(from));

        vm.prank(address(from));
        token.setApprovalForAll(address(this), true);

        token.transferFrom(address(from), address(0xBEEF), 0);

        assertEq(token.getApproved(0), address(0));
        assertEq(token.ownerOf(0), address(0xBEEF));
        assertEq(token.balanceOf(address(0xBEEF)), 1);
        assertEq(token.balanceOf(address(from)), 0);
        assertEq(token.balanceOf(address(this)), 0);
    }

    function testSafeTransferFromToEOA() public {
        ERC721User from = ERC721User(address(token));

        mintOneToFrom(address(from));

        vm.prank(address(from));
        token.setApprovalForAll(address(this), true);
        bool aprv = token.isApprovedForAll(address(from), address(this));
        assertTrue(aprv, "Approval not correct");

        token.safeTransferFrom(address(from), address(0xBEEF), 0);

        assertEq(token.getApproved(0), address(0));
        assertEq(token.ownerOf(0), address(0xBEEF));
        assertEq(token.balanceOf(address(0xBEEF)), 1);
        assertEq(token.balanceOf(address(from)), 0);
        assertEq(token.balanceOf(address(this)), 0);
    }

    function testSafeTransferFromToERC721Recipient() public {
        ERC721User from = ERC721User(address(token));
        ERC721Recipient recipient = new ERC721Recipient();

        mintOneToFrom(address(from));

        vm.prank(address(from));
        token.setApprovalForAll(address(this), true);

        token.safeTransferFrom(address(from), address(recipient), 0);

        assertEq(token.getApproved(0), address(0));
        assertEq(token.ownerOf(0), address(recipient));
        assertEq(token.balanceOf(address(recipient)), 1);
        assertEq(token.balanceOf(address(from)), 0);

        assertEq(recipient.operator(), address(this));
        assertEq(recipient.from(), address(from));
        assertEq(recipient.id(), 0);
        assertBytesEq(recipient.data(), "");
    }

    function testSafeTransferFromToERC721RecipientWithData() public {
        ERC721User from = ERC721User(address(token));
        ERC721Recipient recipient = new ERC721Recipient();

        mintOneToFrom(address(from));

        vm.prank(address(from));
        token.setApprovalForAll(address(this), true);

        token.safeTransferFrom(address(from), address(recipient), 0, "testing 123");

        assertEq(token.getApproved(0), address(0));
        assertEq(token.ownerOf(0), address(recipient));
        assertEq(token.balanceOf(address(recipient)), 1);
        assertEq(token.balanceOf(address(from)), 0);

        assertEq(recipient.operator(), address(this));
        assertEq(recipient.from(), address(from));
        assertEq(recipient.id(), 0);
        assertBytesEq(recipient.data(), "testing 123");
    }

    function testFailApproveUnMinted() public {
        token.approve(address(0xBEEF), 1337);
    }

    function testFailApproveUnAuthorized() public {
        mintOneToFrom(address(0xCAFE));

        token.approve(address(0xBEEF), 0);
    }

    function testFailTransferFromUnOwned() public {
        token.transferFrom(address(0xFEED), address(0xBEEF), 1337);
    }

    function testFailTransferFromWrongFrom() public {
        mintOneToFrom(address(0xCAFE));

        token.transferFrom(address(0xFEED), address(0xBEEF), 0);
    }

    function testFailTransferFromToZero() public {
        mintOneToFrom(address(this));

        token.transferFrom(address(this), address(0), 0);
    }

    function testFailTransferFromNotOwner() public {
        mintOneToFrom(address(0xFEED));

        token.transferFrom(address(0xFEED), address(0xBEEF), 0);
    }

    function testFailSafeTransferFromToNonERC721Recipient() public {
        mintOneToFrom(address(this));

        token.safeTransferFrom(address(this), address(new NonERC721Recipient()), 0);
    }

    function testFailSafeTransferFromToNonERC721RecipientWithData() public {
        mintOneToFrom(address(this));

        token.safeTransferFrom(address(this), address(new NonERC721Recipient()), 0, "testing 123");
    }

    function testFailSafeTransferFromToRevertingERC721Recipient() public {
        mintOneToFrom(address(this));

        token.safeTransferFrom(address(this), address(new RevertingERC721Recipient()), 0);
    }

    function testFailSafeTransferFromToRevertingERC721RecipientWithData() public {
        mintOneToFrom(address(this));

        token.safeTransferFrom(address(this), address(new RevertingERC721Recipient()), 0, "testing 123");
    }

    function testFailSafeTransferFromToERC721RecipientWithWrongReturnData() public {
        mintOneToFrom(address(this));


        token.safeTransferFrom(address(this), address(new WrongReturnDataERC721Recipient()), 0);
    }

    function testFailSafeTransferFromToERC721RecipientWithWrongReturnDataWithData() public {
        mintOneToFrom(address(this));

        token.safeTransferFrom(address(this), address(new WrongReturnDataERC721Recipient()), 0, "testing 123");
    }

}

